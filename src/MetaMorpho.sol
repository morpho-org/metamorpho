// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IMorphoMarketParams} from "./interfaces/IMorphoMarketParams.sol";
import {
    IMetaMorpho, MarketConfig, PendingUint192, PendingAddress, MarketAllocation
} from "./interfaces/IMetaMorpho.sol";
import {Id, MarketParams, Market, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import "./libraries/ConstantsLib.sol";
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
    using MorphoLib for IMorpho;
    using SharesMathLib for uint256;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    /* IMMUTABLES */

    /// @notice The address of the Morpho contract.
    IMorpho public immutable MORPHO;

    /* STORAGE */

    /// @notice The address of the risk manager.
    address public riskManager;

    /// @notice Stores whether an address is an allocator or not.
    mapping(address => bool) internal _isAllocator;

    /// @notice Stores the configuration of each market.
    mapping(Id => MarketConfig) public config;

    /// @notice Stores the pending cap of each market.
    mapping(Id => PendingUint192) public pendingCap;

    /// @dev Stores the order of markets on which liquidity is supplied upon deposit.
    /// @dev Can contain any market. A market is skipped as soon as its supply cap is reached.
    Id[] public supplyQueue;

    /// @dev Stores the order of markets from which liquidity is withdrawn upon withdrawal.
    /// @dev Always contain all non-zero cap markets as well as all markets on which the vault supplies liquidity,
    /// without duplicate.
    Id[] public withdrawQueue;

    /// @notice The pending fee.
    PendingUint192 public pendingFee;

    /// @notice The pending timelock.
    PendingUint192 public pendingTimelock;

    /// @notice The pending guardian.
    PendingAddress public pendingGuardian;

    /// @notice The current fee.
    uint96 public fee;

    /// @notice The fee recipient.
    address public feeRecipient;

    /// @notice The timelock.
    uint256 public timelock;

    /// @notice The guardian. Can be set even without the timelock set.
    address public guardian;

    /// @notice The rewards recipient.
    address public rewardsRecipient;

    /// @notice Stores the total assets managed by this vault when the fee was last accrued.
    uint256 public lastTotalAssets;

    /// @notice Stores the idle liquidity.
    /// @dev The idle liquidity does not generate any interest.
    uint256 public idle;

    /* CONSTRUCTOR */

    /// @dev Constructs the contract.
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
        MORPHO = IMorpho(morpho);

        _checkTimelockBounds(initialTimelock);
        _setTimelock(initialTimelock);

        SafeERC20.safeIncreaseAllowance(IERC20(_asset), morpho, type(uint256).max);
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller doesn't have the risk manager's privilege.
    modifier onlyRiskManager() {
        if (_msgSender() != riskManager && _msgSender() != owner()) revert ErrorsLib.NotRiskManager();

        _;
    }

    /// @dev Reverts if the caller doesn't have the allocator's privilege.
    modifier onlyAllocator() {
        if (!isAllocator(_msgSender())) revert ErrorsLib.NotAllocator();

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
    /// - the timelock has not elapsed since the pending value has been submitted;
    /// - the timelock has expired since the pending value has been submitted.
    modifier withinTimelockWindow(uint256 submittedAt) {
        if (submittedAt == 0) revert ErrorsLib.NoPendingValue();
        if (block.timestamp < submittedAt + timelock) revert ErrorsLib.TimelockNotElapsed();
        if (block.timestamp > submittedAt + timelock + TIMELOCK_EXPIRATION) {
            revert ErrorsLib.TimelockExpirationExceeded();
        }

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    /// @notice Sets `riskManager` to `newRiskManager`.
    function setRiskManager(address newRiskManager) external onlyOwner {
        if (newRiskManager == riskManager) revert ErrorsLib.AlreadySet();

        riskManager = newRiskManager;

        emit EventsLib.SetRiskManager(newRiskManager);
    }

    /// @notice Sets `newAllocator` as an allocator or not (`newIsAllocator`).
    function setIsAllocator(address newAllocator, bool newIsAllocator) external onlyOwner {
        if (_isAllocator[newAllocator] == newIsAllocator) revert ErrorsLib.AlreadySet();

        _isAllocator[newAllocator] = newIsAllocator;

        emit EventsLib.SetIsAllocator(newAllocator, newIsAllocator);
    }

    /// @notice Sets `rewardsRecipient` to `newRewardsRecipient`.
    function setRewardsRecipient(address newRewardsRecipient) external onlyOwner {
        if (newRewardsRecipient == rewardsRecipient) revert ErrorsLib.AlreadySet();

        rewardsRecipient = newRewardsRecipient;

        emit EventsLib.SetRewardsRecipient(newRewardsRecipient);
    }

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
    function submitFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert ErrorsLib.MaxFeeExceeded();
        if (newFee == fee) revert ErrorsLib.AlreadySet();

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
    /// @notice Warning: the guardian has the power to revoke any pending guardian.
    function submitGuardian(address newGuardian) external onlyOwner {
        if (newGuardian == guardian) revert ErrorsLib.AlreadySet();

        if (guardian == address(0)) {
            _setGuardian(newGuardian);
        } else {
            pendingGuardian = PendingAddress(newGuardian, uint64(block.timestamp));

            emit EventsLib.SubmitGuardian(newGuardian);
        }
    }

    /* ONLY RISK MANAGER FUNCTIONS */

    /// @notice Submits a `newMarketCap` for the market defined by `marketParams`.
    function submitCap(MarketParams memory marketParams, uint256 newMarketCap) external onlyRiskManager {
        Id id = marketParams.id();
        if (marketParams.loanToken != asset()) revert ErrorsLib.InconsistentAsset(id);
        if (MORPHO.lastUpdate(id) == 0) revert ErrorsLib.MarketNotCreated();

        uint256 marketCap = config[id].cap;
        if (newMarketCap == marketCap) revert ErrorsLib.AlreadySet();

        if (newMarketCap < marketCap) {
            _setCap(id, newMarketCap.toUint192());
        } else {
            pendingCap[id] = PendingUint192(newMarketCap.toUint192(), uint64(block.timestamp));

            emit EventsLib.SubmitCap(id, newMarketCap);
        }
    }

    /* ONLY ALLOCATOR FUNCTIONS */

    /// @notice Sets `supplyQueue` to `newSupplyQueue`.
    /// @dev The supply queue can be a set containing duplicate markets, but it would only increase the cost of
    /// depositing to the vault.
    function setSupplyQueue(Id[] calldata newSupplyQueue) external onlyAllocator {
        uint256 length = newSupplyQueue.length;

        for (uint256 i; i < length; ++i) {
            if (config[newSupplyQueue[i]].cap == 0) revert ErrorsLib.UnauthorizedMarket(newSupplyQueue[i]);
        }

        supplyQueue = newSupplyQueue;

        emit EventsLib.SetSupplyQueue(msg.sender, newSupplyQueue);
    }

    /// @notice Sets the withdraw queue as a permutation of the previous one, although markets with zero cap and zero
    /// vault's supply can be removed.
    /// @notice Removing a market requires the vault to have 0 supply on it; but anyone can supply on behalf of the
    /// vault so the call to `sortWithdrawQueue` can be griefed by a frontrun. To circumvent this, the allocator can
    /// simply bundle a reallocation that withdraws max from this market with a call to `sortWithdrawQueue`.
    /// @param indexes The indexes of each market in the previous withdraw queue, in the new withdraw queue's order.
    function sortWithdrawQueue(uint256[] calldata indexes) external onlyAllocator {
        uint256 newLength = indexes.length;
        uint256 currLength = withdrawQueue.length;

        bool[] memory seen = new bool[](currLength);
        Id[] memory newWithdrawQueue = new Id[](newLength);

        for (uint256 i; i < newLength; ++i) {
            uint256 prevIndex = indexes[i];
            Id id = withdrawQueue[prevIndex];

            // If prevIndex >= currLength, reverts with native "Index out of bounds".
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
                    revert ErrorsLib.MissingMarket(id);
                }

                delete config[id].withdrawRank;
            }
        }

        withdrawQueue = newWithdrawQueue;

        emit EventsLib.SetWithdrawQueue(msg.sender, newWithdrawQueue);
    }

    /// @notice Reallocates the vault's liquidity by withdrawing some (based on `withdrawn`) then supplying (based on
    /// `supplied`).
    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied)
        external
        onlyAllocator
    {
        uint256 totalWithdrawn;
        uint256 nbWithdrawn = withdrawn.length;

        for (uint256 i; i < nbWithdrawn; ++i) {
            MarketAllocation memory allocation = withdrawn[i];

            if (allocation.marketParams.loanToken != asset()) {
                revert ErrorsLib.InconsistentAsset(allocation.marketParams.id());
            }

            // Guarantees that unknown frontrunning donations can be withdrawn, in order to disable a market.
            if (allocation.shares == type(uint256).max) {
                allocation.shares = MORPHO.supplyShares(allocation.marketParams.id(), address(this));
            }

            (uint256 withdrawnAssets,) = MORPHO.withdraw(
                allocation.marketParams, allocation.assets, allocation.shares, address(this), address(this)
            );

            totalWithdrawn += withdrawnAssets;
        }

        uint256 totalSupplied;
        uint256 nbSupplied = supplied.length;

        for (uint256 i; i < nbSupplied; ++i) {
            MarketAllocation memory allocation = supplied[i];

            (uint256 suppliedAssets,) =
                MORPHO.supply(allocation.marketParams, allocation.assets, allocation.shares, address(this), hex"");

            totalSupplied += suppliedAssets;

            Id id = allocation.marketParams.id();
            if (_supplyBalance(allocation.marketParams) > config[id].cap) {
                revert ErrorsLib.SupplyCapExceeded(id);
            }
        }

        if (totalWithdrawn > totalSupplied) {
            idle += totalWithdrawn - totalSupplied;
        } else {
            uint256 idleSupplied = totalSupplied - totalWithdrawn;
            if (idle < idleSupplied) revert ErrorsLib.InsufficientIdle();

            idle -= idleSupplied;
        }
    }

    /* ONLY GUARDIAN FUNCTIONS */

    /// @notice Revokes the `pendingTimelock`.
    function revokeTimelock() external onlyGuardian {
        emit EventsLib.RevokeTimelock(msg.sender, pendingTimelock);

        delete pendingTimelock;
    }

    /// @notice Revokes the `pendingGuardian`.
    function revokeGuardian() external onlyGuardian {
        emit EventsLib.RevokeGuardian(msg.sender, pendingGuardian);

        delete pendingGuardian;
    }

    /// @notice Revokes the pending cap of the market defined by `id`.
    function revokeCap(Id id) external onlyGuardian {
        emit EventsLib.RevokeCap(msg.sender, id, pendingCap[id]);

        delete pendingCap[id];
    }

    /* EXTERNAL */

    /// @notice Returns the size of the supply queue.
    function supplyQueueSize() external view returns (uint256) {
        return supplyQueue.length;
    }

    /// @notice Returns the size of the withdraw queue.
    function withdrawQueueSize() external view returns (uint256) {
        return withdrawQueue.length;
    }

    /// @notice Accepts the `pendingTimelock`.
    function acceptTimelock() external withinTimelockWindow(pendingTimelock.submittedAt) {
        _setTimelock(pendingTimelock.value);
    }

    /// @notice Accepts the `pendingFee`.
    function acceptFee() external withinTimelockWindow(pendingFee.submittedAt) {
        _setFee(pendingFee.value);
    }

    /// @notice Accepts the `pendingGuardian`.
    function acceptGuardian() external withinTimelockWindow(pendingGuardian.submittedAt) {
        _setGuardian(pendingGuardian.value);
    }

    /// @notice Accepts the pending cap of the market defined by `id`.
    function acceptCap(Id id) external withinTimelockWindow(pendingCap[id].submittedAt) {
        _setCap(id, pendingCap[id].value);
    }

    /// @notice Transfers `token` rewards collected by the vault to the `rewardsRecipient`.
    /// @dev Can be used to extract any token that would be stuck on the contract as well.
    function transferRewards(address token) external {
        if (rewardsRecipient == address(0)) revert ErrorsLib.ZeroAddress();

        uint256 amount = IERC20(token).balanceOf(address(this));
        if (token == asset()) amount -= idle;

        SafeERC20.safeTransfer(IERC20(token), rewardsRecipient, amount);

        emit EventsLib.TransferRewards(msg.sender, rewardsRecipient, token, amount);
    }

    /* PUBLIC */

    /// @notice Returns whether `target` is an allocator or not.
    function isAllocator(address target) public view returns (bool) {
        return _isAllocator[target] || target == riskManager || target == owner();
    }

    /* ERC4626 (PUBLIC) */

    /// @inheritdoc IERC20Metadata
    function decimals() public view override(IERC20Metadata, ERC20, ERC4626) returns (uint8) {
        return ERC4626.decimals();
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) public view override(IERC4626, ERC4626) returns (uint256 assets) {
        (assets,,) = _maxWithdraw(owner);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) public view override(IERC4626, ERC4626) returns (uint256) {
        (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets) = _maxWithdraw(owner);

        return _convertToSharesWithFeeAccrued(assets, newTotalSupply, newTotalAssets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public override(IERC4626, ERC4626) returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        shares = _convertToSharesWithFeeAccrued(assets, totalSupply(), newTotalAssets, Math.Rounding.Floor);
        _deposit(_msgSender(), receiver, assets, shares);

        _updateLastTotalAssets(newTotalAssets + assets);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override(IERC4626, ERC4626) returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        assets = _convertToAssetsWithFeeAccrued(shares, totalSupply(), newTotalAssets, Math.Rounding.Ceil);
        _deposit(_msgSender(), receiver, assets, shares);

        _updateLastTotalAssets(newTotalAssets + assets);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(IERC4626, ERC4626)
        returns (uint256 shares)
    {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxWithdraw` and optimistically withdraw assets.

        shares = _convertToSharesWithFeeAccrued(assets, totalSupply(), newTotalAssets, Math.Rounding.Ceil);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        _updateLastTotalAssets(newTotalAssets - assets);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner)
        public
        override(IERC4626, ERC4626)
        returns (uint256 assets)
    {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxRedeem` and optimistically redeem shares.

        assets = _convertToAssetsWithFeeAccrued(shares, totalSupply(), newTotalAssets, Math.Rounding.Floor);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        _updateLastTotalAssets(newTotalAssets - assets);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view override(IERC4626, ERC4626) returns (uint256 assets) {
        uint256 nbMarkets = withdrawQueue.length;

        for (uint256 i; i < nbMarkets; ++i) {
            assets += _supplyBalance(_marketParams(withdrawQueue[i]));
        }

        assets += idle;
    }

    /* ERC4626 (INTERNAL) */

    /// @inheritdoc ERC4626
    function _decimalsOffset() internal pure override returns (uint8) {
        return DECIMALS_OFFSET;
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

        assets = _convertToAssetsWithFeeAccrued(balanceOf(owner), newTotalSupply, newTotalAssets, Math.Rounding.Floor);
        assets -= _staticWithdrawMorpho(assets);
    }

    /// @inheritdoc ERC4626
    /// @dev The accrual of the performance fee is taken into account in the conversion.
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToSharesWithFeeAccrued(assets, totalSupply() + feeShares, newTotalAssets, rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev The accrual of fees is taken into account in the conversion.
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToAssetsWithFeeAccrued(shares, totalSupply() + feeShares, newTotalAssets, rounding);
    }

    /// @dev Returns the amount of shares that the vault would exchange for the amount of `assets` provided, in an ideal
    /// scenario where all the conditions are met.
    /// @dev It assumes the performance fee has been accrued and thus takes into account `newTotalSupply` and
    /// `newTotalAssets`.
    function _convertToSharesWithFeeAccrued(
        uint256 assets,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal pure returns (uint256) {
        return assets.mulDiv(newTotalSupply + 10 ** _decimalsOffset(), newTotalAssets + 1, rounding);
    }

    /// @dev Returns the amount of assets that the Vault would exchange for the amount of `shares` provided, in an ideal
    /// scenario where all the conditions are met.
    /// @dev It assumes the performance fee has been accrued and thus takes into account `newTotalSupply` and
    /// `newTotalAssets`.
    function _convertToAssetsWithFeeAccrued(
        uint256 shares,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal pure returns (uint256) {
        return shares.mulDiv(newTotalAssets + 1, newTotalSupply + 10 ** _decimalsOffset(), rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev Used in mint or deposit to deposit the underlying asset to Morpho markets.
    function _deposit(address caller, address owner, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, owner, assets, shares);

        _supplyMorpho(assets);
    }

    /// @inheritdoc ERC4626
    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Morpho markets.
    /// @dev Reverts when withdrawing "too much", depending on 3 cases:
    /// 1. "ERC20: burn amount exceeds balance" when withdrawing more `owner`'s than balance but less than vault's total
    /// assets.
    /// 2. "withdraw failed on Morpho" when withdrawing more than vault's total assets.
    /// 3. "withdraw failed on Morpho" when withdrawing more than `owner`'s balance but less than the current available
    /// liquidity.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        if (_withdrawMorpho(assets) != 0) revert ErrorsLib.WithdrawMorphoFailed();

        super._withdraw(caller, receiver, owner, assets, shares);
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
        if (newTimelock > MAX_TIMELOCK) revert ErrorsLib.AboveMaxTimelock();
        if (newTimelock < MIN_TIMELOCK) revert ErrorsLib.BelowMinTimelock();
    }

    /// @dev Sets `timelock` to `newTimelock`.
    function _setTimelock(uint256 newTimelock) internal {
        timelock = newTimelock;

        emit EventsLib.SetTimelock(newTimelock);

        delete pendingTimelock;
    }

    /// @dev Sets `guardian` to `newGuardian`.
    function _setGuardian(address newGuardian) internal {
        guardian = newGuardian;

        emit EventsLib.SetGuardian(newGuardian);

        delete pendingGuardian;
    }

    /// @dev Sets the cap of the market defined by `id` to `marketCap`.
    function _setCap(Id id, uint192 marketCap) internal {
        MarketConfig storage marketConfig = config[id];

        if (marketCap > 0 && marketConfig.withdrawRank == 0) {
            supplyQueue.push(id);
            withdrawQueue.push(id);

            if (withdrawQueue.length > MAX_QUEUE_SIZE) revert ErrorsLib.MaxQueueSizeExceeded();

            // Safe "unchecked" cast because withdrawQueue.length <= MAX_QUEUE_SIZE.
            marketConfig.withdrawRank = uint64(withdrawQueue.length);
        }

        marketConfig.cap = marketCap;

        emit EventsLib.SetCap(id, marketCap);

        delete pendingCap[id];
    }

    /// @dev Sets `fee` to `newFee`.
    function _setFee(uint256 newFee) internal {
        if (newFee != 0 && feeRecipient == address(0)) revert ErrorsLib.ZeroFeeRecipient();

        // Accrue interest using the previous fee set before changing it.
        _updateLastTotalAssets(_accrueFee());

        // Safe "unchecked" cast because newFee <= MAX_FEE.
        fee = uint96(newFee);

        emit EventsLib.SetFee(newFee);

        delete pendingFee;
    }

    /* LIQUIDITY ALLOCATION */

    /// @dev Supplies `assets` to Morpho and increase the idle liquidity if necessary.
    function _supplyMorpho(uint256 assets) internal {
        uint256 nbMarkets = supplyQueue.length;

        for (uint256 i; i < nbMarkets; ++i) {
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

        uint256 nbMarkets = withdrawQueue.length;

        for (uint256 i; i < nbMarkets; ++i) {
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

    /// @dev Fakes a withdraw of `assets` from the idle liquidity and Morpho if necessary.
    /// @return remaining The assets left to be withdrawn.
    function _staticWithdrawMorpho(uint256 assets) internal view returns (uint256 remaining) {
        (remaining,) = _withdrawIdle(assets);

        if (remaining == 0) return 0;

        uint256 nbMarkets = withdrawQueue.length;

        for (uint256 i; i < nbMarkets; ++i) {
            Id id = withdrawQueue[i];
            MarketParams memory marketParams = _marketParams(id);

            // The vault withdrawing from Morpho cannot fail because:
            // 1. oracle.price() is never called (the vault doesn't borrow)
            // 2. `_withdrawable` caps to the liquidity available on Morpho
            // 3. virtually accruing interest didn't fail in `_withdrawable`
            remaining -= _withdrawable(marketParams, id);

            if (remaining == 0) return 0;
        }
    }

    /// @dev Withdraws `assets` from the idle liquidity.
    /// @return The assets withdrawn from the idle liquidity.
    /// @return The new `idle` liquidity value.
    function _withdrawIdle(uint256 assets) internal view returns (uint256, uint256) {
        return (assets.zeroFloorSub(idle), idle.zeroFloorSub(assets));
    }

    /// @dev Returns the suppliable amount of assets on the market defined by `marketParams`.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _suppliable(MarketParams memory marketParams, Id id) internal view returns (uint256) {
        uint256 marketCap = config[id].cap;
        if (marketCap == 0) return 0;

        return marketCap.zeroFloorSub(_supplyBalance(marketParams));
    }

    /// @dev Returns the withdrawable amount of assets from the market defined by `marketParams`.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _withdrawable(MarketParams memory marketParams, Id id) internal view returns (uint256) {
        uint256 supplyShares = MORPHO.supplyShares(id, address(this));
        (uint256 totalSupplyAssets, uint256 totalSupplyShares, uint256 totalBorrowAssets,) =
            MORPHO.expectedMarketBalances(marketParams);

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

        if (feeShares != 0 && feeRecipient != address(0)) _mint(feeRecipient, feeShares);
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
            feeShares = feeAssets.mulDiv(
                totalSupply() + 10 ** _decimalsOffset(), newTotalAssets - feeAssets + 1, Math.Rounding.Floor
            );
        }
    }
}
