// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IMorphoMarketParams} from "./interfaces/IMorphoMarketParams.sol";
import {
    IMetaMorpho, MarketConfig, PendingUint192, PendingAddress, MarketAllocation
} from "./interfaces/IMetaMorpho.sol";
import {Id, MarketParams, Market, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import {ConstantsLib} from "./libraries/ConstantsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {WAD} from "@morpho-blue/libraries/MathLib.sol";
import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";
import {SafeCast} from "@openzeppelin/utils/math/SafeCast.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";
import {MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";
import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

import {Multicall} from "@openzeppelin/utils/Multicall.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/access/Ownable2Step.sol";
import {ERC20Permit} from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20, IERC4626, ERC20, ERC4626, Math, SafeERC20} from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

/// @title MetaMorpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice ERC4626 compliant vault allowing users to deposit assets to Morpho.
contract MetaMorpho is ERC4626, ERC20Permit, Ownable2Step, Multicall, IMetaMorpho {
    using Math for uint256;
    using UtilsLib for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using MorphoLib for IMorpho;
    using SharesMathLib for uint256;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    /* IMMUTABLES */

    /// @notice The address of the Morpho contract.
    IMorpho public immutable MORPHO;

    /* STORAGE */

    /// @notice The address of the curator.
    address public curator;

    /// @notice Stores whether an address is an allocator or not.
    mapping(address => bool) public isAllocator;

    /// @notice The current guardian. Can be set even without the timelock set.
    address public guardian;

    /// @notice Stores the current configuration of each market.
    mapping(Id => MarketConfig) public config;

    /// @notice The current timelock.
    uint256 public timelock;

    /// @notice The current fee.
    uint96 public fee;

    /// @notice The fee recipient.
    address public feeRecipient;

    /// @notice The rewards recipient.
    address public rewardsRecipient;

    /// @notice The pending guardian.
    PendingAddress public pendingGuardian;

    /// @notice Stores the pending cap for each market.
    mapping(Id => PendingUint192) public pendingCap;

    /// @notice The pending timelock.
    PendingUint192 public pendingTimelock;

    /// @notice The pending fee.
    PendingUint192 public pendingFee;

    /// @dev Stores the order of markets on which liquidity is supplied upon deposit.
    /// @dev Can contain any market. A market is skipped as soon as its supply cap is reached.
    Id[] public supplyQueue;

    /// @dev Stores the order of markets from which liquidity is withdrawn upon withdrawal.
    /// @dev Always contain all non-zero cap markets as well as all markets on which the vault supplies liquidity,
    /// without duplicate.
    Id[] public withdrawQueue;

    /// @notice Stores the idle liquidity.
    /// @dev The idle liquidity does not generate any interest.
    uint256 public idle;

    /// @notice Stores the total assets managed by this vault when the fee was last accrued.
    uint256 public lastTotalAssets;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param owner The owner of the contract.
    /// @param morpho The address of the Morpho contract.
    /// @param initialTimelock The initial timelock.
    /// @param _asset The address of the underlying asset.
    /// @param _name The name of the vault.
    /// @param _symbol The symbol of the vault.
    constructor(
        address owner,
        address morpho,
        uint256 initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(IERC20(_asset)) ERC20Permit(_name) ERC20(_name, _symbol) Ownable(owner) {
        if (morpho == address(0)) revert ErrorsLib.ZeroAddress();

        MORPHO = IMorpho(morpho);

        _checkTimelockBounds(initialTimelock);
        _setTimelock(initialTimelock);

        IERC20(_asset).forceApprove(morpho, type(uint256).max);
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller doesn't have the curator role.
    modifier onlyCuratorRole() {
        address sender = _msgSender();
        if (sender != curator && sender != owner()) revert ErrorsLib.NotCuratorRole();

        _;
    }

    /// @dev Reverts if the caller doesn't have the allocator role.
    modifier onlyAllocatorRole() {
        address sender = _msgSender();
        if (!isAllocator[sender] && sender != curator && sender != owner()) {
            revert ErrorsLib.NotAllocatorRole();
        }

        _;
    }

    /// @dev Reverts if the caller is not the `guardian`.
    modifier onlyGuardian() {
        if (_msgSender() != guardian) revert ErrorsLib.NotGuardian();

        _;
    }

    /// @dev Makes sure conditions are met to accept a pending value.
    /// @dev Reverts if:
    /// - there's no pending value;
    /// - the timelock has not elapsed since the pending value has been submitted.
    modifier afterTimelock(uint256 submittedAt) {
        if (submittedAt == 0) revert ErrorsLib.NoPendingValue();
        if (block.timestamp < submittedAt + timelock) revert ErrorsLib.TimelockNotElapsed();

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    /// @notice Sets `curator` to `newCurator`.
    function setCurator(address newCurator) external onlyOwner {
        if (newCurator == curator) revert ErrorsLib.AlreadySet();

        curator = newCurator;

        emit EventsLib.SetCurator(newCurator);
    }

    /// @notice Sets `newAllocator` as an allocator or not (`newIsAllocator`).
    function setIsAllocator(address newAllocator, bool newIsAllocator) external onlyOwner {
        if (isAllocator[newAllocator] == newIsAllocator) revert ErrorsLib.AlreadySet();

        isAllocator[newAllocator] = newIsAllocator;

        emit EventsLib.SetIsAllocator(newAllocator, newIsAllocator);
    }

    /// @notice Sets `rewardsRecipient` to `newRewardsRecipient`.
    function setRewardsRecipient(address newRewardsRecipient) external onlyOwner {
        if (newRewardsRecipient == rewardsRecipient) revert ErrorsLib.AlreadySet();

        rewardsRecipient = newRewardsRecipient;

        emit EventsLib.SetRewardsRecipient(newRewardsRecipient);
    }

    /// @notice Submits a `newTimelock`.
    /// @dev In case the new timelock is higher than the current one, the timelock is set immediately.
    /// @dev Warning: Submitting a timelock will overwrite the current pending timelock.
    function submitTimelock(uint256 newTimelock) external onlyOwner {
        if (newTimelock == timelock) revert ErrorsLib.AlreadySet();
        _checkTimelockBounds(newTimelock);

        if (newTimelock > timelock) {
            _setTimelock(newTimelock);
        } else {
            // Safe "unchecked" cast because newTimelock <= MAX_TIMELOCK.
            pendingTimelock = PendingUint192(uint192(newTimelock), uint64(block.timestamp));

            emit EventsLib.SubmitTimelock(newTimelock);
        }
    }

    /// @notice Submits a `newFee`.
    /// @dev In case the new fee is lower than the current one, the fee is set immediately.
    /// @dev Warning: Submitting a fee will overwrite the current pending fee.
    function submitFee(uint256 newFee) external onlyOwner {
        if (newFee == fee) revert ErrorsLib.AlreadySet();
        if (newFee > ConstantsLib.MAX_FEE) revert ErrorsLib.MaxFeeExceeded();

        if (newFee < fee) {
            _setFee(newFee);
        } else {
            // Safe "unchecked" cast because newFee <= MAX_FEE.
            pendingFee = PendingUint192(uint192(newFee), uint64(block.timestamp));

            emit EventsLib.SubmitFee(newFee);
        }
    }

    /// @notice Sets `feeRecipient` to `newFeeRecipient`.
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == feeRecipient) revert ErrorsLib.AlreadySet();
        if (newFeeRecipient == address(0) && fee != 0) revert ErrorsLib.ZeroFeeRecipient();

        // Accrue interest to the previous fee recipient set before changing it.
        _updateLastTotalAssets(_accrueFee());

        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

    /// @notice Submits a `newGuardian`.
    /// @notice Warning: a malicious guardian could disrupt the vault's operation, and would have the power to revoke
    /// any pending guardian.
    /// @dev In case there is no guardian, the gardian is set immediately.
    /// @dev Warning: Submitting a gardian will overwrite the current pending gardian.
    function submitGuardian(address newGuardian) external onlyOwner {
        if (newGuardian == guardian) revert ErrorsLib.AlreadySet();

        if (guardian == address(0)) {
            _setGuardian(newGuardian);
        } else {
            pendingGuardian = PendingAddress(newGuardian, uint64(block.timestamp));

            emit EventsLib.SubmitGuardian(newGuardian);
        }
    }

    /* ONLY CURATOR FUNCTIONS */

    /// @notice Submits a `newSupplyCap` for the market defined by `marketParams`.
    /// @dev In case the new cap is lower than the current one, the cap is set immediately.
    /// @dev Warning: Submitting a cap will overwrite the current pending cap.
    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external onlyCuratorRole {
        Id id = marketParams.id();
        if (marketParams.loanToken != asset()) revert ErrorsLib.InconsistentAsset(id);
        if (MORPHO.lastUpdate(id) == 0) revert ErrorsLib.MarketNotCreated();

        uint256 supplyCap = config[id].cap;
        if (newSupplyCap == supplyCap) revert ErrorsLib.AlreadySet();

        if (newSupplyCap < supplyCap) {
            _setCap(id, newSupplyCap.toUint192());
        } else {
            pendingCap[id] = PendingUint192(newSupplyCap.toUint192(), uint64(block.timestamp));

            emit EventsLib.SubmitCap(_msgSender(), id, newSupplyCap);
        }
    }

    /* ONLY ALLOCATOR FUNCTIONS */

    /// @notice Sets `supplyQueue` to `newSupplyQueue`.
    /// @param newSupplyQueue is an array of enabled markets, and can contain duplicate markets, but it would only
    /// increase the cost of depositing to the vault.
    function setSupplyQueue(Id[] calldata newSupplyQueue) external onlyAllocatorRole {
        uint256 length = newSupplyQueue.length;

        if (length > ConstantsLib.MAX_QUEUE_LENGTH) revert ErrorsLib.MaxQueueLengthExceeded();

        for (uint256 i; i < length; ++i) {
            if (config[newSupplyQueue[i]].cap == 0) revert ErrorsLib.UnauthorizedMarket(newSupplyQueue[i]);
        }

        supplyQueue = newSupplyQueue;

        emit EventsLib.SetSupplyQueue(_msgSender(), newSupplyQueue);
    }

    /// @notice Sets the withdraw queue as a permutation of the previous one, although markets with both zero cap and
    /// zero vault's supply can be removed from the permutation.
    /// @notice This is the only entry point to disable a market.
    /// @notice Removing a market requires the vault to have 0 supply on it; but anyone can supply on behalf of the
    /// vault so the call to `sortWithdrawQueue` can be griefed by a frontrun. To circumvent this, the allocator can
    /// simply bundle a reallocation that withdraws max from this market with a call to `sortWithdrawQueue`.
    /// @param indexes The indexes of each market in the previous withdraw queue, in the new withdraw queue's order.
    function updateWithdrawQueue(uint256[] calldata indexes) external onlyAllocatorRole {
        uint256 newLength = indexes.length;
        uint256 currLength = withdrawQueue.length;

        bool[] memory seen = new bool[](currLength);
        Id[] memory newWithdrawQueue = new Id[](newLength);

        for (uint256 i; i < newLength; ++i) {
            uint256 prevIndex = indexes[i];

            // If prevIndex >= currLength, it will revert with native "Index out of bounds".
            Id id = withdrawQueue[prevIndex];
            if (seen[prevIndex]) revert ErrorsLib.DuplicateMarket(id);
            seen[prevIndex] = true;

            newWithdrawQueue[i] = id;

            // Safe "unchecked" cast because i < currLength.
            config[id].withdrawRank = uint64(i + 1);
        }

        for (uint256 i; i < currLength; ++i) {
            if (!seen[i]) {
                Id id = withdrawQueue[i];

                if (MORPHO.supplyShares(id, address(this)) != 0 || config[id].cap != 0) {
                    revert ErrorsLib.InvalidMarketRemoval(id);
                }

                delete config[id].withdrawRank;
            }
        }

        withdrawQueue = newWithdrawQueue;

        emit EventsLib.SetWithdrawQueue(_msgSender(), newWithdrawQueue);
    }

    /// @notice Reallocates the vault's liquidity by withdrawing some (based on `withdrawn`) then supplying (based on
    /// `supplied`).
    /// @dev The allocator can withdraw from any market, even if it's not in the withdraw queue, as long as the loan
    /// token of the market is the same as the vault's asset.
    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied)
        external
        onlyAllocatorRole
    {
        uint256 totalWithdrawn;
        for (uint256 i; i < withdrawn.length; ++i) {
            MarketAllocation memory allocation = withdrawn[i];
            Id id = allocation.marketParams.id();

            if (allocation.marketParams.loanToken != asset()) revert ErrorsLib.InconsistentAsset(id);

            // Guarantees that unknown frontrunning donations can be withdrawn, in order to disable a market.
            uint256 shares;
            if (allocation.assets == type(uint256).max) {
                shares = MORPHO.supplyShares(id, address(this));

                allocation.assets = 0;
            }

            (uint256 withdrawnAssets, uint256 withdrawnShares) =
                MORPHO.withdraw(allocation.marketParams, allocation.assets, shares, address(this), address(this));

            totalWithdrawn += withdrawnAssets;

            emit EventsLib.ReallocateWithdraw(_msgSender(), id, withdrawnAssets, withdrawnShares);
        }

        uint256 totalSupplied;
        for (uint256 i; i < supplied.length; ++i) {
            MarketAllocation memory allocation = supplied[i];
            Id id = allocation.marketParams.id();
            uint256 supplyCap = config[id].cap;

            if (supplyCap == 0) revert ErrorsLib.UnauthorizedMarket(id);

            (uint256 suppliedAssets, uint256 suppliedShares) =
                MORPHO.supply(allocation.marketParams, allocation.assets, 0, address(this), hex"");

            if (_supplyBalance(allocation.marketParams) > supplyCap) {
                revert ErrorsLib.SupplyCapExceeded(id);
            }

            totalSupplied += suppliedAssets;

            emit EventsLib.ReallocateSupply(_msgSender(), id, suppliedAssets, suppliedShares);
        }

        uint256 newIdle;
        if (totalWithdrawn > totalSupplied) {
            newIdle = idle + totalWithdrawn - totalSupplied;
        } else {
            uint256 idleSupplied = totalSupplied - totalWithdrawn;
            if (idle < idleSupplied) revert ErrorsLib.InsufficientIdle();

            newIdle = idle - idleSupplied;
        }

        idle = newIdle;

        emit EventsLib.ReallocateIdle(_msgSender(), newIdle);
    }

    /* ONLY GUARDIAN FUNCTIONS */

    /// @notice Revokes the `pendingTimelock`.
    function revokePendingTimelock() external onlyGuardian {
        delete pendingTimelock;

        emit EventsLib.RevokePendingTimelock(_msgSender());
    }

    /// @notice Revokes the `pendingGuardian`.
    function revokePendingGuardian() external onlyGuardian {
        delete pendingGuardian;

        emit EventsLib.RevokePendingGuardian(_msgSender());
    }

    /// @notice Revokes the pending cap of the market defined by `id`.
    function revokePendingCap(Id id) external onlyGuardian {
        delete pendingCap[id];

        emit EventsLib.RevokePendingCap(_msgSender(), id);
    }

    /* EXTERNAL */

    /// @notice Returns the length of the supply queue.
    function supplyQueueLength() external view returns (uint256) {
        return supplyQueue.length;
    }

    /// @notice Returns the length of the withdraw queue.
    function withdrawQueueLength() external view returns (uint256) {
        return withdrawQueue.length;
    }

    /// @notice Accepts the `pendingTimelock`.
    function acceptTimelock() external afterTimelock(pendingTimelock.submittedAt) {
        _setTimelock(pendingTimelock.value);
    }

    /// @notice Accepts the `pendingFee`.
    function acceptFee() external afterTimelock(pendingFee.submittedAt) {
        _setFee(pendingFee.value);
    }

    /// @notice Accepts the `pendingGuardian`.
    function acceptGuardian() external afterTimelock(pendingGuardian.submittedAt) {
        _setGuardian(pendingGuardian.value);
    }

    /// @notice Accepts the pending cap of the market defined by `id`.
    function acceptCap(Id id) external afterTimelock(pendingCap[id].submittedAt) {
        _setCap(id, pendingCap[id].value);
    }

    /// @notice Transfers `token` rewards collected by the vault to the `rewardsRecipient`.
    /// @dev Can be used to extract any token that would be stuck on the contract as well.
    function transferRewards(address token) external {
        if (rewardsRecipient == address(0)) revert ErrorsLib.ZeroAddress();

        uint256 amount = IERC20(token).balanceOf(address(this));
        if (token == asset()) amount -= idle;

        IERC20(token).safeTransfer(rewardsRecipient, amount);

        emit EventsLib.TransferRewards(_msgSender(), token, amount);
    }

    /* ERC4626 (PUBLIC) */

    /// @inheritdoc IERC20Metadata
    function decimals() public view override(IERC20Metadata, ERC20, ERC4626) returns (uint8) {
        return ERC4626.decimals();
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be lower than the actual amount of assets that can be withdrawn by `owner` due to conversion
    /// roundings between shares and assets.
    function maxWithdraw(address owner) public view override(IERC4626, ERC4626) returns (uint256 assets) {
        (assets,,) = _maxWithdraw(owner);
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be lower than the actual amount of shares that can be redeemed by `owner` due to conversion
    /// roundings between shares and assets.
    function maxRedeem(address owner) public view override(IERC4626, ERC4626) returns (uint256) {
        (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets) = _maxWithdraw(owner);

        return _convertToSharesWithTotals(assets, newTotalSupply, newTotalAssets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public override(IERC4626, ERC4626) returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        shares = _convertToSharesWithTotals(assets, totalSupply(), newTotalAssets, Math.Rounding.Floor);
        _deposit(_msgSender(), receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override(IERC4626, ERC4626) returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        assets = _convertToAssetsWithTotals(shares, totalSupply(), newTotalAssets, Math.Rounding.Ceil);
        _deposit(_msgSender(), receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(IERC4626, ERC4626)
        returns (uint256 shares)
    {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxWithdraw` and optimistically withdraw assets.

        shares = _convertToSharesWithTotals(assets, totalSupply(), newTotalAssets, Math.Rounding.Ceil);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner)
        public
        override(IERC4626, ERC4626)
        returns (uint256 assets)
    {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxRedeem` and optimistically redeem shares.

        assets = _convertToAssetsWithTotals(shares, totalSupply(), newTotalAssets, Math.Rounding.Floor);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view override(IERC4626, ERC4626) returns (uint256 assets) {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            assets += _supplyBalance(_marketParams(withdrawQueue[i]));
        }

        assets += idle;
    }

    /* ERC4626 (INTERNAL) */

    /// @inheritdoc ERC4626
    function _decimalsOffset() internal pure override returns (uint8) {
        return ConstantsLib.DECIMALS_OFFSET;
    }

    /// @dev Returns the maximum amount of asset (`assets`) that the `owner` can withdraw from the vault, as well as the
    /// new vault's total supply (`newTotalSupply`) and total assets (`newTotalAssets`).
    function _maxWithdraw(address owner)
        internal
        view
        returns (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets)
    {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares();
        newTotalSupply = totalSupply() + feeShares;

        assets = _convertToAssetsWithTotals(balanceOf(owner), newTotalSupply, newTotalAssets, Math.Rounding.Floor);
        assets -= _simulateWithdrawMorpho(assets);
    }

    /// @inheritdoc ERC4626
    /// @dev The accrual of performance fees is taken into account in the conversion.
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToSharesWithTotals(assets, totalSupply() + feeShares, newTotalAssets, rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev The accrual of performance fees is taken into account in the conversion.
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToAssetsWithTotals(shares, totalSupply() + feeShares, newTotalAssets, rounding);
    }

    /// @dev Returns the amount of shares that the vault would exchange for the amount of `assets` provided.
    /// @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
    function _convertToSharesWithTotals(
        uint256 assets,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal pure returns (uint256) {
        return assets.mulDiv(newTotalSupply + 10 ** _decimalsOffset(), newTotalAssets + 1, rounding);
    }

    /// @dev Returns the amount of assets that the vault would exchange for the amount of `shares` provided.
    /// @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
    function _convertToAssetsWithTotals(
        uint256 shares,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal pure returns (uint256) {
        return shares.mulDiv(newTotalAssets + 1, newTotalSupply + 10 ** _decimalsOffset(), rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev Used in mint or deposit to deposit the underlying asset to Morpho markets.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares);

        _supplyMorpho(assets);

        // `newTotalAssets + assets` cannot be used as input because of rounding errors so we must use `totalAssets`.
        _updateLastTotalAssets(totalAssets());
    }

    /// @inheritdoc ERC4626
    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Morpho markets.
    /// @dev Depending on 4 cases, reverts when withdrawing "too much" with:
    /// 1. ERC20InsufficientAllowance when withdrawing more than `caller`'s allowance.
    /// 2. ERC20InsufficientBalance when withdrawing more than `owner`'s balance but less than vault's total assets.
    /// 3. WithdrawMorphoFailed when withdrawing more than vault's total assets.
    /// 4. WithdrawMorphoFailed when withdrawing more than `owner`'s balance but less than the available liquidity.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        if (_withdrawMorpho(assets) != 0) revert ErrorsLib.WithdrawMorphoFailed();

        super._withdraw(caller, receiver, owner, assets, shares);

        // `newTotalAssets - assets` cannot be used as input because of rounding errors so we must use `totalAssets`.
        _updateLastTotalAssets(totalAssets());
    }

    /* INTERNAL */

    /// @dev Returns the market params of the market defined by `id`.
    function _marketParams(Id id) internal view returns (MarketParams memory) {
        return IMorphoMarketParams(address(MORPHO)).idToMarketParams(id);
    }

    /// @dev Returns the vault's balance the market defined by `marketParams`.
    function _supplyBalance(MarketParams memory marketParams) internal view returns (uint256) {
        return MORPHO.expectedSupplyBalance(marketParams, address(this));
    }

    /// @dev Reverts if `newTimelock` is not within the bounds.
    function _checkTimelockBounds(uint256 newTimelock) internal pure {
        if (newTimelock > ConstantsLib.MAX_TIMELOCK) revert ErrorsLib.AboveMaxTimelock();
        if (newTimelock < ConstantsLib.MIN_TIMELOCK) revert ErrorsLib.BelowMinTimelock();
    }

    /// @dev Sets `timelock` to `newTimelock`.
    function _setTimelock(uint256 newTimelock) internal {
        timelock = newTimelock;

        emit EventsLib.SetTimelock(_msgSender(), newTimelock);

        delete pendingTimelock;
    }

    /// @dev Sets `guardian` to `newGuardian`.
    function _setGuardian(address newGuardian) internal {
        guardian = newGuardian;

        emit EventsLib.SetGuardian(_msgSender(), newGuardian);

        delete pendingGuardian;
    }

    /// @dev Sets the cap of the market defined by `id` to `supplyCap`.
    function _setCap(Id id, uint192 supplyCap) internal {
        MarketConfig storage marketConfig = config[id];

        if (supplyCap > 0 && marketConfig.withdrawRank == 0) {
            supplyQueue.push(id);
            withdrawQueue.push(id);

            if (
                supplyQueue.length > ConstantsLib.MAX_QUEUE_LENGTH
                    || withdrawQueue.length > ConstantsLib.MAX_QUEUE_LENGTH
            ) {
                revert ErrorsLib.MaxQueueLengthExceeded();
            }

            // Safe "unchecked" cast because withdrawQueue.length <= MAX_QUEUE_LENGTH.
            marketConfig.withdrawRank = uint64(withdrawQueue.length);
        }

        marketConfig.cap = supplyCap;

        emit EventsLib.SetCap(_msgSender(), id, supplyCap);

        delete pendingCap[id];
    }

    /// @dev Sets `fee` to `newFee`.
    function _setFee(uint256 newFee) internal {
        if (newFee != 0 && feeRecipient == address(0)) revert ErrorsLib.ZeroFeeRecipient();

        // Accrue interest using the previous fee set before changing it.
        _updateLastTotalAssets(_accrueFee());

        // Safe "unchecked" cast because newFee <= MAX_FEE.
        fee = uint96(newFee);

        emit EventsLib.SetFee(_msgSender(), newFee);

        delete pendingFee;
    }

    /* LIQUIDITY ALLOCATION */

    /// @dev Supplies `assets` to Morpho and increase the idle liquidity if necessary.
    function _supplyMorpho(uint256 assets) internal {
        for (uint256 i; i < supplyQueue.length; ++i) {
            Id id = supplyQueue[i];
            MarketParams memory marketParams = _marketParams(id);

            uint256 toSupply = UtilsLib.min(_suppliable(marketParams, id), assets);

            if (toSupply > 0) {
                // Using try/catch to skip markets that revert.
                try MORPHO.supply(marketParams, toSupply, 0, address(this), hex"") {
                    assets -= toSupply;
                } catch {}
            }

            if (assets == 0) return;
        }

        idle += assets;
    }

    /// @dev Withdraws `assets` from the idle liquidity and Morpho if necessary.
    /// @return remaining The assets left to be withdrawn.
    function _withdrawMorpho(uint256 assets) internal returns (uint256 remaining) {
        (remaining, idle) = _withdrawIdle(assets);

        if (remaining == 0) return 0;

        for (uint256 i; i < withdrawQueue.length; ++i) {
            Id id = withdrawQueue[i];
            MarketParams memory marketParams = _marketParams(id);

            uint256 toWithdraw = UtilsLib.min(_withdrawable(marketParams, id), remaining);

            if (toWithdraw > 0) {
                // Using try/catch to skip markets that revert.
                try MORPHO.withdraw(marketParams, toWithdraw, 0, address(this), address(this)) {
                    remaining -= toWithdraw;
                } catch {}
            }

            if (remaining == 0) return 0;
        }
    }

    /// @dev Simulates a withdraw of `assets` from the idle liquidity and Morpho if necessary.
    /// @return remaining The assets left to be withdrawn.
    function _simulateWithdrawMorpho(uint256 assets) internal view returns (uint256 remaining) {
        (remaining,) = _withdrawIdle(assets);

        if (remaining == 0) return 0;

        for (uint256 i; i < withdrawQueue.length; ++i) {
            Id id = withdrawQueue[i];
            MarketParams memory marketParams = _marketParams(id);

            // The vault withdrawing from Morpho cannot fail because:
            // 1. oracle.price() is never called (the vault doesn't borrow)
            // 2. `_withdrawable` caps to the liquidity available on Morpho
            // 3. virtually accruing interest didn't fail in `_withdrawable`
            remaining -= UtilsLib.min(_withdrawable(marketParams, id), remaining);

            if (remaining == 0) return 0;
        }
    }

    /// @dev Withdraws `assets` from the idle liquidity.
    /// @return The remaining assets to withdraw.
    /// @return The new `idle` liquidity value.
    function _withdrawIdle(uint256 assets) internal view returns (uint256, uint256) {
        return (assets.zeroFloorSub(idle), idle.zeroFloorSub(assets));
    }

    /// @dev Returns the suppliable amount of assets on the market defined by `marketParams`.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _suppliable(MarketParams memory marketParams, Id id) internal view returns (uint256) {
        uint256 supplyCap = config[id].cap;
        if (supplyCap == 0) return 0;

        return supplyCap.zeroFloorSub(_supplyBalance(marketParams));
    }

    /// @dev Returns the withdrawable amount of assets from the market defined by `marketParams`.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _withdrawable(MarketParams memory marketParams, Id id) internal view returns (uint256) {
        uint256 supplyShares = MORPHO.supplyShares(id, address(this));
        (uint256 totalSupplyAssets, uint256 totalSupplyShares, uint256 totalBorrowAssets,) =
            MORPHO.expectedMarketBalances(marketParams);

        // Inside a flashloan callback, liquidity on Morpho Blue may be limited to the singleton's balance.
        uint256 availableLiquidity = UtilsLib.min(
            totalSupplyAssets - totalBorrowAssets, ERC20(marketParams.loanToken).balanceOf(address(MORPHO))
        );

        return UtilsLib.min(supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares), availableLiquidity);
    }

    /* FEE MANAGEMENT */

    /// @dev Updates `lastTotalAssets` to `newTotalAssets`.
    function _updateLastTotalAssets(uint256 newTotalAssets) internal {
        lastTotalAssets = newTotalAssets;

        emit EventsLib.UpdateLastTotalAssets(newTotalAssets);
    }

    /// @dev Accrues the fee and mints the fee shares to the fee recipient.
    /// @return newTotalAssets The new vault's total assets.
    function _accrueFee() internal returns (uint256 newTotalAssets) {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares();

        if (feeShares != 0) {
            _mint(feeRecipient, feeShares);

            emit EventsLib.AccrueFee(feeShares);
        }
    }

    /// @dev Computes and returns the fee shares (`feeShares`) to mint and the new vault's total assets
    /// (`newTotalAssets`).
    function _accruedFeeShares() internal view returns (uint256 feeShares, uint256 newTotalAssets) {
        newTotalAssets = totalAssets();

        uint256 totalInterest = newTotalAssets.zeroFloorSub(lastTotalAssets);
        if (totalInterest != 0 && fee != 0) {
            uint256 feeAssets = totalInterest.mulDiv(fee, WAD);
            // The fee assets is subtracted from the total assets in this calculation to compensate for the fact
            // that total assets is already increased by the total interest (including the fee assets).
            feeShares =
                _convertToSharesWithTotals(feeAssets, totalSupply(), newTotalAssets - feeAssets, Math.Rounding.Floor);
        }
    }
}
