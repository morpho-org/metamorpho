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
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";
import {MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";
import {SafeCast} from "@openzeppelin/utils/math/SafeCast.sol";

import {Multicall} from "@openzeppelin/utils/Multicall.sol";
import {Ownable2Step} from "@openzeppelin/access/Ownable2Step.sol";
import {IERC20Metadata, ERC20Permit} from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
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

    /// @notice Stores whether `target` is an allocator or not.
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

    /// @notice The guardian.
    address public guardian;

    /// @notice The rewards distributor.
    address public rewardsDistributor;

    /// @notice Stores the total assets owned by this vault when the fee was last accrued.
    uint256 public lastTotalAssets;

    /// @notice Stores the idle liquidity.
    /// @dev The idle liquidity does not generate any interest.
    uint256 public idle;

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
    ) ERC4626(IERC20(_asset)) ERC20Permit(_name) ERC20(_name, _symbol) {
        require(initialTimelock <= MAX_TIMELOCK, ErrorsLib.MAX_TIMELOCK_EXCEEDED);

        _transferOwnership(owner);

        MORPHO = IMorpho(morpho);

        _setTimelock(initialTimelock);

        SafeERC20.safeApprove(IERC20(_asset), morpho, type(uint256).max);
    }

    /* MODIFIERS */

    /// @dev Reverts if the caller is not the `riskManager`.
    modifier onlyRiskManager() {
        require(_msgSender() == riskManager || _msgSender() == owner(), ErrorsLib.NOT_RISK_MANAGER);

        _;
    }

    /// @dev Reverts if the caller is not the `guardian`.
    modifier onlyGuardian() {
        require(_msgSender() == guardian, ErrorsLib.NOT_GUARDIAN);

        _;
    }

    /// @dev Reverts if the caller is not an allocator.
    modifier onlyAllocator() {
        require(isAllocator(_msgSender()), ErrorsLib.NOT_ALLOCATOR);

        _;
    }

    /// @dev Makes sure conditions are met to accept a pending value.
    /// @dev Reverts if:
    /// - there's no pending value;
    /// - the timelock has not elapsed;
    /// - the timelock has expired.
    modifier timelockElapsed(uint256 submittedAt) {
        require(submittedAt != 0, ErrorsLib.NO_PENDING_VALUE);
        require(block.timestamp >= submittedAt + timelock, ErrorsLib.TIMELOCK_NOT_ELAPSED);
        require(block.timestamp <= submittedAt + timelock + TIMELOCK_EXPIRATION, ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED);

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    /// @notice Sets `riskManager` to `newRiskManager`.
    function setRiskManager(address newRiskManager) external onlyOwner {
        require(newRiskManager != riskManager, ErrorsLib.ALREADY_SET);

        riskManager = newRiskManager;

        emit EventsLib.SetRiskManager(newRiskManager);
    }

    /// @notice Sets `newAllocator` as an allocator or not (`newIsAllocator`).
    function setIsAllocator(address newAllocator, bool newIsAllocator) external onlyOwner {
        require(_isAllocator[newAllocator] != newIsAllocator, ErrorsLib.ALREADY_SET);

        _isAllocator[newAllocator] = newIsAllocator;

        emit EventsLib.SetIsAllocator(newAllocator, newIsAllocator);
    }

    /// @notice Submits a `newTimelock`.
    function submitTimelock(uint256 newTimelock) external onlyOwner {
        require(newTimelock <= MAX_TIMELOCK, ErrorsLib.MAX_TIMELOCK_EXCEEDED);
        require(newTimelock != timelock, ErrorsLib.ALREADY_SET);

        if (newTimelock > timelock || timelock == 0) {
            _setTimelock(newTimelock);
        } else {
            // Safe "unchecked" cast because newTimelock <= MAX_TIMELOCK.
            pendingTimelock = PendingUint192(uint192(newTimelock), uint64(block.timestamp));

            emit EventsLib.SubmitTimelock(newTimelock);
        }
    }

    /// @notice Sets `rewardsDistributor` to `newRewardsDistributor`.
    function setRewardsDistributor(address newRewardsDistributor) external onlyOwner {
        require(newRewardsDistributor != rewardsDistributor, ErrorsLib.ALREADY_SET);

        rewardsDistributor = newRewardsDistributor;

        emit EventsLib.SetRewardsDistributor(newRewardsDistributor);
    }

    /// @notice Accepts the `pendingTimelock`.
    function acceptTimelock() external timelockElapsed(pendingTimelock.submittedAt) onlyOwner {
        _setTimelock(pendingTimelock.value);
    }

    /// @notice Submits a `newFee`.
    function submitFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_FEE, ErrorsLib.MAX_FEE_EXCEEDED);
        require(newFee != fee, ErrorsLib.ALREADY_SET);

        if (newFee < fee || timelock == 0) {
            _setFee(newFee);
        } else {
            // Safe "unchecked" cast because newFee <= MAX_FEE.
            pendingFee = PendingUint192(uint192(newFee), uint64(block.timestamp));

            emit EventsLib.SubmitFee(newFee);
        }
    }

    /// @notice Accepts the `pendingFee`.
    function acceptFee() external timelockElapsed(pendingFee.submittedAt) onlyOwner {
        // Accrue interest using the previous fee set before changing it.
        _updateLastTotalAssets(_accrueFee());

        _setFee(pendingFee.value);
    }

    /// @notice Sets `feeRecipient` to `newFeeRecipient`.
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET);
        require(newFeeRecipient != address(0) || fee == 0, ErrorsLib.ZERO_FEE_RECIPIENT);

        // Accrue interest to the previous fee recipient set before changing it.
        _updateLastTotalAssets(_accrueFee());

        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

    /// @notice Submits a `newGuardian`.
    function submitGuardian(address newGuardian) external onlyOwner {
        require(timelock != 0, ErrorsLib.NO_TIMELOCK);
        require(newGuardian != guardian, ErrorsLib.ALREADY_SET);

        if (guardian == address(0)) {
            _setGuardian(newGuardian);
        } else {
            pendingGuardian = PendingAddress(newGuardian, uint64(block.timestamp));

            emit EventsLib.SubmitGuardian(newGuardian);
        }
    }

    /// @notice Accepts the `pendingGuardian`.
    function acceptGuardian() external timelockElapsed(pendingGuardian.submittedAt) onlyOwner {
        _setGuardian(pendingGuardian.value);
    }

    /* ONLY RISK MANAGER FUNCTIONS */

    /// @notice Submits a `newMarketCap` for the market defined by `marketParams`.
    function submitCap(MarketParams memory marketParams, uint256 newMarketCap) external onlyRiskManager {
        require(marketParams.loanToken == asset(), ErrorsLib.INCONSISTENT_ASSET);

        Id id = marketParams.id();
        require(MORPHO.lastUpdate(id) != 0, ErrorsLib.MARKET_NOT_CREATED);

        uint256 marketCap = config[id].cap;
        require(newMarketCap != marketCap, ErrorsLib.ALREADY_SET);

        if (newMarketCap < marketCap || timelock == 0) {
            _setCap(id, newMarketCap.toUint192());
        } else {
            pendingCap[id] = PendingUint192(newMarketCap.toUint192(), uint64(block.timestamp));

            emit EventsLib.SubmitCap(id, newMarketCap);
        }
    }

    /// @notice Accepts the pending cap of the market defined by `id`.
    function acceptCap(Id id) external timelockElapsed(pendingCap[id].submittedAt) onlyRiskManager {
        _setCap(id, pendingCap[id].value);
    }

    /* ONLY ALLOCATOR FUNCTIONS */

    /// @notice Sets `supplyQueue` to `newSupplyQueue`.
    /// @dev The supply queue can be a set containing duplicate markets, but it would only increase the cost of
    /// depositing
    /// to the vault.
    function setSupplyQueue(Id[] calldata newSupplyQueue) external onlyAllocator {
        uint256 length = newSupplyQueue.length;

        for (uint256 i; i < length; ++i) {
            require(config[newSupplyQueue[i]].cap > 0, ErrorsLib.UNAUTHORIZED_MARKET);
        }

        supplyQueue = newSupplyQueue;

        emit EventsLib.SetSupplyQueue(msg.sender, newSupplyQueue);
    }

    /// @dev Sets the withdraw queue as a permutation of the previous one, although markets with zero cap and zero
    /// vault's supply can be removed.
    /// @param indexes The indexes of the markets in the previous withdraw queue.
    function sortWithdrawQueue(uint256[] calldata indexes) external onlyAllocator {
        uint256 newLength = indexes.length;
        uint256 currLength = withdrawQueue.length;

        bool[] memory seen = new bool[](currLength);
        Id[] memory newWithdrawQueue = new Id[](newLength);

        for (uint256 i; i < newLength; ++i) {
            uint256 prevIndex = indexes[i];

            // If prevIndex >= currLength, reverts with native "Index out of bounds".
            require(!seen[prevIndex], ErrorsLib.DUPLICATE_MARKET);

            seen[prevIndex] = true;

            Id id = withdrawQueue[prevIndex];

            newWithdrawQueue[i] = id;

            // Safe "unchecked" cast because i < currLength.
            config[id].withdrawRank = uint64(i + 1);
        }

        for (uint256 i; i < currLength; ++i) {
            if (!seen[i]) {
                Id id = withdrawQueue[i];

                require(MORPHO.supplyShares(id, address(this)) == 0 && config[id].cap == 0, ErrorsLib.MISSING_MARKET);

                delete config[id].withdrawRank;
            }
        }

        withdrawQueue = newWithdrawQueue;

        emit EventsLib.SetWithdrawQueue(msg.sender, newWithdrawQueue);
    }

    /// @notice Reallocates the vault's liquidity to the markets defined by `withdrawn` and `supplied`.
    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied)
        external
        onlyAllocator
    {
        uint256 totalWithdrawn;
        uint256 nbWithdrawn = withdrawn.length;

        for (uint256 i; i < nbWithdrawn; ++i) {
            MarketAllocation memory allocation = withdrawn[i];

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

            require(
                _supplyBalance(allocation.marketParams) <= config[allocation.marketParams.id()].cap,
                ErrorsLib.SUPPLY_CAP_EXCEEDED
            );
        }

        if (totalWithdrawn > totalSupplied) {
            idle += totalWithdrawn - totalSupplied;
        } else {
            uint256 idleSupplied = totalSupplied - totalWithdrawn;
            require(idle >= idleSupplied, ErrorsLib.INSUFFICIENT_IDLE);

            idle -= idleSupplied;
        }
    }

    /* EXTERNAL */

    /// @notice Transfers `token` rewards collected by the vault to the `rewardsDistributor`.
    /// @dev Can be used to extract any token that would be stuck on the contract as well.
    function transferRewards(address token) external {
        require(rewardsDistributor != address(0), ErrorsLib.ZERO_ADDRESS);

        uint256 amount = IERC20(token).balanceOf(address(this));
        if (token == asset()) amount -= idle;

        SafeERC20.safeTransfer(IERC20(token), rewardsDistributor, amount);

        emit EventsLib.TransferRewards(msg.sender, rewardsDistributor, token, amount);
    }

    /* ONLY GUARDIAN FUNCTIONS */

    /// @notice Revokes the `pendingTimelock`.
    function revokeTimelock() external onlyGuardian {
        emit EventsLib.RevokeTimelock(msg.sender, pendingTimelock);

        delete pendingTimelock;
    }

    /// @notice Revokes the pending cap of the market defined by `id`.
    function revokeCap(Id id) external onlyGuardian {
        emit EventsLib.RevokeCap(msg.sender, id, pendingCap[id]);

        delete pendingCap[id];
    }

    /// @notice Revokes the `pendingGuardian`.
    function revokeGuardian() external onlyGuardian {
        emit EventsLib.RevokeGuardian(msg.sender, pendingGuardian);

        delete pendingGuardian;
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
        (assets,) = _maxWithdraw(owner);
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) public view override(IERC4626, ERC4626) returns (uint256) {
        (uint256 assets, uint256 newTotalAssets) = _maxWithdraw(owner);

        return _convertToSharesWithFeeAccrued(assets, newTotalAssets, Math.Rounding.Down);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public override(IERC4626, ERC4626) returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        shares = _convertToSharesWithFeeAccrued(assets, newTotalAssets, Math.Rounding.Down);
        _deposit(_msgSender(), receiver, assets, shares);

        _updateLastTotalAssets(newTotalAssets + assets);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override(IERC4626, ERC4626) returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        assets = _convertToAssetsWithFeeAccrued(shares, newTotalAssets, Math.Rounding.Up);
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

        shares = _convertToSharesWithFeeAccrued(assets, newTotalAssets, Math.Rounding.Up);
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

        assets = _convertToAssetsWithFeeAccrued(shares, newTotalAssets, Math.Rounding.Down);
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
    /// new vault's total assets (`newTotalAssets`).
    function _maxWithdraw(address owner) internal view returns (uint256 assets, uint256 newTotalAssets) {
        (, newTotalAssets) = _accruedFeeShares();

        assets = super.maxWithdraw(owner);
        assets -= _staticWithdrawMorpho(assets);
    }

    /// @inheritdoc ERC4626
    /// @dev The accrual of fees is taken into account in the conversion.
    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return assets.mulDiv(totalSupply() + feeShares + 10 ** _decimalsOffset(), newTotalAssets + 1, rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev The accrual of fees is taken into account in the conversion.
    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return shares.mulDiv(newTotalAssets + 1, totalSupply() + feeShares + 10 ** _decimalsOffset(), rounding);
    }

    /// @dev Returns the amount of shares that the vault would exchange for the amount of assets provided, in an ideal
    /// scenario where all the conditions are met.
    /// @dev It assumes that fees have been accrued before calling this function.
    function _convertToSharesWithFeeAccrued(uint256 assets, uint256 newTotalAssets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), newTotalAssets + 1, rounding);
    }

    /// @dev Returns the amount of assets that the Vault would exchange for the amount of shares provided, in an ideal
    /// scenario where all the conditions are met.
    /// @dev It assumes that fees have been accrued before calling this function.
    function _convertToAssetsWithFeeAccrued(uint256 shares, uint256 newTotalAssets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return shares.mulDiv(newTotalAssets + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
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
        require(_withdrawMorpho(assets) == 0, ErrorsLib.WITHDRAW_FAILED_MORPHO);

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

            require(withdrawQueue.length <= MAX_QUEUE_SIZE, ErrorsLib.MAX_QUEUE_SIZE_EXCEEDED);

            // Safe "unchecked" cast because withdrawQueue.length <= MAX_QUEUE_SIZE.
            marketConfig.withdrawRank = uint64(withdrawQueue.length);
        }

        marketConfig.cap = marketCap;

        emit EventsLib.SetCap(id, marketCap);

        delete pendingCap[id];
    }

    /// @dev Sets `fee` to `newFee`.
    function _setFee(uint256 newFee) internal {
        require(newFee == 0 || feeRecipient != address(0), ErrorsLib.ZERO_FEE_RECIPIENT);

        // Safe "unchecked" cast because newFee <= MAX_FEE.
        fee = uint96(newFee);

        emit EventsLib.SetFee(newFee);

        delete pendingFee;
    }

    /* LIQUIDITY ALLOCATION */

    /// @dev Supplies `assets` to Morpho and the idle liquidity if necessary.
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
    function _withdrawMorpho(uint256 assets) internal returns (uint256) {
        (assets, idle) = _withdrawIdle(assets);

        if (assets == 0) return 0;

        uint256 nbMarkets = withdrawQueue.length;

        for (uint256 i; i < nbMarkets; ++i) {
            Id id = withdrawQueue[i];
            MarketParams memory marketParams = _marketParams(id);

            uint256 toWithdraw = UtilsLib.min(_withdrawable(marketParams, id), assets);

            if (toWithdraw > 0) {
                // Using try/catch to skip markets that revert.
                try MORPHO.withdraw(marketParams, toWithdraw, 0, address(this), address(this)) {
                    assets -= toWithdraw;
                } catch {}
            }

            if (assets == 0) return 0;
        }

        return assets;
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

        return remaining;
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
        uint256 availableLiquidity = totalSupplyAssets - totalBorrowAssets;

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
                totalSupply() + 10 ** _decimalsOffset(), newTotalAssets - feeAssets + 1, Math.Rounding.Down
            );
        }
    }
}
