// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {
    MarketConfig,
    PendingUint192,
    PendingAddress,
    MarketAllocation,
    IMetaMorphoBase,
    IMetaMorphoStaticTyping
} from "./interfaces/IMetaMorpho.sol";
import {Id, MarketParams, Market, IMorpho} from "../lib/morpho-blue/src/interfaces/IMorpho.sol";

import {PendingUint192, PendingAddress, PendingLib} from "./libraries/PendingLib.sol";
import {ConstantsLib} from "./libraries/ConstantsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {WAD} from "../lib/morpho-blue/src/libraries/MathLib.sol";
import {UtilsLib} from "../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {SafeCast} from "../lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {SharesMathLib} from "../lib/morpho-blue/src/libraries/SharesMathLib.sol";
import {MorphoLib} from "../lib/morpho-blue/src/libraries/periphery/MorphoLib.sol";
import {MarketParamsLib} from "../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {IERC20Metadata} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MorphoBalancesLib} from "../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

import {Multicall} from "../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";
import {Ownable2Step, Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import {ERC20Permit} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {
    IERC20,
    IERC4626,
    ERC20,
    ERC4626,
    Math,
    SafeERC20
} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

/// @title MetaMorpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice ERC4626 compliant vault allowing users to deposit assets to Morpho.
contract MetaMorpho is ERC4626, ERC20Permit, Ownable2Step, Multicall, IMetaMorphoStaticTyping {
    using Math for uint256;
    using UtilsLib for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using MorphoLib for IMorpho;
    using SharesMathLib for uint256;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;
    using PendingLib for MarketConfig;
    using PendingLib for PendingUint192;
    using PendingLib for PendingAddress;

    /* IMMUTABLES */

    /// @inheritdoc IMetaMorphoBase
    IMorpho public immutable MORPHO;

    /// @inheritdoc IMetaMorphoBase
    uint8 public immutable DECIMALS_OFFSET;

    /* STORAGE */

    /// @inheritdoc IMetaMorphoBase
    address public curator;

    /// @inheritdoc IMetaMorphoBase
    mapping(address => bool) public isAllocator;

    /// @inheritdoc IMetaMorphoBase
    address public guardian;

    /// @inheritdoc IMetaMorphoStaticTyping
    mapping(Id => MarketConfig) public config;

    /// @inheritdoc IMetaMorphoBase
    uint256 public timelock;

    /// @inheritdoc IMetaMorphoStaticTyping
    PendingAddress public pendingGuardian;

    /// @inheritdoc IMetaMorphoStaticTyping
    mapping(Id => PendingUint192) public pendingCap;

    /// @inheritdoc IMetaMorphoStaticTyping
    PendingUint192 public pendingTimelock;

    /// @inheritdoc IMetaMorphoBase
    uint96 public fee;

    /// @inheritdoc IMetaMorphoBase
    address public feeRecipient;

    /// @inheritdoc IMetaMorphoBase
    address public skimRecipient;

    /// @inheritdoc IMetaMorphoBase
    Id[] public supplyQueue;

    /// @inheritdoc IMetaMorphoBase
    Id[] public withdrawQueue;

    /// @inheritdoc IMetaMorphoBase
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
        DECIMALS_OFFSET = uint8(uint256(18).zeroFloorSub(IERC20Metadata(_asset).decimals()));

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

    /// @dev Reverts if the caller doesn't have the guardian role.
    modifier onlyGuardianRole() {
        if (_msgSender() != owner() && _msgSender() != guardian) revert ErrorsLib.NotGuardianRole();

        _;
    }

    /// @dev Reverts if the caller doesn't have the curator nor the guardian role.
    modifier onlyCuratorOrGuardianRole() {
        if (_msgSender() != guardian && _msgSender() != curator && _msgSender() != owner()) {
            revert ErrorsLib.NotCuratorNorGuardianRole();
        }

        _;
    }

    /// @dev Makes sure conditions are met to accept a pending value.
    /// @dev Reverts if:
    /// - there's no pending value;
    /// - the timelock has not elapsed since the pending value has been submitted.
    modifier afterTimelock(uint256 validAt) {
        if (validAt == 0) revert ErrorsLib.NoPendingValue();
        if (block.timestamp < validAt) revert ErrorsLib.TimelockNotElapsed();

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    /// @inheritdoc IMetaMorphoBase
    function setCurator(address newCurator) external onlyOwner {
        if (newCurator == curator) revert ErrorsLib.AlreadySet();

        curator = newCurator;

        emit EventsLib.SetCurator(newCurator);
    }

    /// @inheritdoc IMetaMorphoBase
    function setIsAllocator(address newAllocator, bool newIsAllocator) external onlyOwner {
        if (isAllocator[newAllocator] == newIsAllocator) revert ErrorsLib.AlreadySet();

        isAllocator[newAllocator] = newIsAllocator;

        emit EventsLib.SetIsAllocator(newAllocator, newIsAllocator);
    }

    /// @inheritdoc IMetaMorphoBase
    function setSkimRecipient(address newSkimRecipient) external onlyOwner {
        if (newSkimRecipient == skimRecipient) revert ErrorsLib.AlreadySet();

        skimRecipient = newSkimRecipient;

        emit EventsLib.SetSkimRecipient(newSkimRecipient);
    }

    /// @inheritdoc IMetaMorphoBase
    function submitTimelock(uint256 newTimelock) external onlyOwner {
        if (newTimelock == timelock) revert ErrorsLib.AlreadySet();
        if (pendingTimelock.validAt != 0) revert ErrorsLib.AlreadyPending();
        _checkTimelockBounds(newTimelock);

        if (newTimelock > timelock) {
            _setTimelock(newTimelock);
        } else {
            // Safe "unchecked" cast because newTimelock <= MAX_TIMELOCK.
            pendingTimelock.update(uint184(newTimelock), timelock);

            emit EventsLib.SubmitTimelock(newTimelock);
        }
    }

    /// @inheritdoc IMetaMorphoBase
    function setFee(uint256 newFee) external onlyOwner {
        if (newFee == fee) revert ErrorsLib.AlreadySet();
        if (newFee > ConstantsLib.MAX_FEE) revert ErrorsLib.MaxFeeExceeded();
        if (newFee != 0 && feeRecipient == address(0)) revert ErrorsLib.ZeroFeeRecipient();

        // Accrue fee using the previous fee set before changing it.
        _updateLastTotalAssets(_accrueFee());

        // Safe "unchecked" cast because newFee <= MAX_FEE.
        fee = uint96(newFee);

        emit EventsLib.SetFee(_msgSender(), fee);
    }

    /// @inheritdoc IMetaMorphoBase
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        if (newFeeRecipient == feeRecipient) revert ErrorsLib.AlreadySet();
        if (newFeeRecipient == address(0) && fee != 0) revert ErrorsLib.ZeroFeeRecipient();

        // Accrue fee to the previous fee recipient set before changing it.
        _updateLastTotalAssets(_accrueFee());

        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

    /// @inheritdoc IMetaMorphoBase
    function submitGuardian(address newGuardian) external onlyOwner {
        if (newGuardian == guardian) revert ErrorsLib.AlreadySet();
        if (pendingGuardian.validAt != 0) revert ErrorsLib.AlreadyPending();

        if (guardian == address(0)) {
            _setGuardian(newGuardian);
        } else {
            pendingGuardian.update(newGuardian, timelock);

            emit EventsLib.SubmitGuardian(newGuardian);
        }
    }

    /* ONLY CURATOR FUNCTIONS */

    /// @inheritdoc IMetaMorphoBase
    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external onlyCuratorRole {
        Id id = marketParams.id();
        if (marketParams.loanToken != asset()) revert ErrorsLib.InconsistentAsset(id);
        if (MORPHO.lastUpdate(id) == 0) revert ErrorsLib.MarketNotCreated();
        if (pendingCap[id].validAt != 0) revert ErrorsLib.AlreadyPending();
        if (config[id].removableAt != 0) revert ErrorsLib.PendingRemoval();
        uint256 supplyCap = config[id].cap;
        if (newSupplyCap == supplyCap) revert ErrorsLib.AlreadySet();

        if (newSupplyCap < supplyCap) {
            _setCap(marketParams, id, newSupplyCap.toUint184());
        } else {
            pendingCap[id].update(newSupplyCap.toUint184(), timelock);

            emit EventsLib.SubmitCap(_msgSender(), id, newSupplyCap);
        }
    }

    /// @inheritdoc IMetaMorphoBase
    function submitMarketRemoval(MarketParams memory marketParams) external onlyCuratorRole {
        Id id = marketParams.id();
        if (config[id].removableAt != 0) revert ErrorsLib.AlreadyPending();
        if (config[id].cap != 0) revert ErrorsLib.NonZeroCap();
        if (!config[id].enabled) revert ErrorsLib.MarketNotEnabled(id);
        if (pendingCap[id].validAt != 0) revert ErrorsLib.PendingCap(id);

        // Safe "unchecked" cast because timelock <= MAX_TIMELOCK.
        config[id].removableAt = uint64(block.timestamp + timelock);

        emit EventsLib.SubmitMarketRemoval(_msgSender(), id);
    }

    /* ONLY ALLOCATOR FUNCTIONS */

    /// @inheritdoc IMetaMorphoBase
    function setSupplyQueue(Id[] calldata newSupplyQueue) external onlyAllocatorRole {
        uint256 length = newSupplyQueue.length;

        if (length > ConstantsLib.MAX_QUEUE_LENGTH) revert ErrorsLib.MaxQueueLengthExceeded();

        for (uint256 i; i < length; ++i) {
            if (config[newSupplyQueue[i]].cap == 0) revert ErrorsLib.UnauthorizedMarket(newSupplyQueue[i]);
        }

        supplyQueue = newSupplyQueue;

        emit EventsLib.SetSupplyQueue(_msgSender(), newSupplyQueue);
    }

    /// @inheritdoc IMetaMorphoBase
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
        }

        for (uint256 i; i < currLength; ++i) {
            if (!seen[i]) {
                Id id = withdrawQueue[i];

                if (config[id].cap != 0) revert ErrorsLib.InvalidMarketRemovalNonZeroCap(id);
                if (pendingCap[id].validAt != 0) revert ErrorsLib.PendingCap(id);

                if (MORPHO.supplyShares(id, address(this)) != 0) {
                    if (config[id].removableAt == 0) revert ErrorsLib.InvalidMarketRemovalNonZeroSupply(id);

                    if (block.timestamp < config[id].removableAt) {
                        revert ErrorsLib.InvalidMarketRemovalTimelockNotElapsed(id);
                    }
                }

                delete config[id];
            }
        }

        withdrawQueue = newWithdrawQueue;

        emit EventsLib.SetWithdrawQueue(_msgSender(), newWithdrawQueue);
    }

    /// @inheritdoc IMetaMorphoBase
    function reallocate(MarketAllocation[] calldata allocations) external onlyAllocatorRole {
        uint256 totalSupplied;
        uint256 totalWithdrawn;
        for (uint256 i; i < allocations.length; ++i) {
            MarketAllocation memory allocation = allocations[i];
            Id id = allocation.marketParams.id();

            (uint256 supplyAssets, uint256 supplyShares,) = _accruedSupplyBalance(allocation.marketParams, id);
            uint256 withdrawn = supplyAssets.zeroFloorSub(allocation.assets);

            if (withdrawn > 0) {
                if (!config[id].enabled) revert ErrorsLib.MarketNotEnabled(id);

                // Guarantees that unknown frontrunning donations can be withdrawn, in order to disable a market.
                uint256 shares;
                if (allocation.assets == 0) {
                    shares = supplyShares;
                    withdrawn = 0;
                }

                (uint256 withdrawnAssets, uint256 withdrawnShares) =
                    MORPHO.withdraw(allocation.marketParams, withdrawn, shares, address(this), address(this));

                emit EventsLib.ReallocateWithdraw(_msgSender(), id, withdrawnAssets, withdrawnShares);

                totalWithdrawn += withdrawnAssets;
            } else {
                uint256 suppliedAssets = allocation.assets == type(uint256).max
                    ? totalWithdrawn.zeroFloorSub(totalSupplied)
                    : allocation.assets.zeroFloorSub(supplyAssets);

                if (suppliedAssets == 0) continue;

                uint256 supplyCap = config[id].cap;
                if (supplyCap == 0) revert ErrorsLib.UnauthorizedMarket(id);

                if (supplyAssets + suppliedAssets > supplyCap) revert ErrorsLib.SupplyCapExceeded(id);

                // The market's loan asset is guaranteed to be the vault's asset because it has a non-zero supply cap.
                (, uint256 suppliedShares) =
                    MORPHO.supply(allocation.marketParams, suppliedAssets, 0, address(this), hex"");

                emit EventsLib.ReallocateSupply(_msgSender(), id, suppliedAssets, suppliedShares);

                totalSupplied += suppliedAssets;
            }
        }

        if (totalWithdrawn != totalSupplied) revert ErrorsLib.InconsistentReallocation();
    }

    /* REVOKE FUNCTIONS */

    /// @inheritdoc IMetaMorphoBase
    function revokePendingTimelock() external onlyGuardianRole {
        delete pendingTimelock;

        emit EventsLib.RevokePendingTimelock(_msgSender());
    }

    /// @inheritdoc IMetaMorphoBase
    function revokePendingGuardian() external onlyGuardianRole {
        delete pendingGuardian;

        emit EventsLib.RevokePendingGuardian(_msgSender());
    }

    /// @inheritdoc IMetaMorphoBase
    function revokePendingCap(Id id) external onlyCuratorOrGuardianRole {
        delete pendingCap[id];

        emit EventsLib.RevokePendingCap(_msgSender(), id);
    }

    /// @inheritdoc IMetaMorphoBase
    function revokePendingMarketRemoval(Id id) external onlyCuratorOrGuardianRole {
        delete config[id].removableAt;

        emit EventsLib.RevokePendingMarketRemoval(_msgSender(), id);
    }

    /* EXTERNAL */

    /// @inheritdoc IMetaMorphoBase
    function supplyQueueLength() external view returns (uint256) {
        return supplyQueue.length;
    }

    /// @inheritdoc IMetaMorphoBase
    function withdrawQueueLength() external view returns (uint256) {
        return withdrawQueue.length;
    }

    /// @inheritdoc IMetaMorphoBase
    function acceptTimelock() external afterTimelock(pendingTimelock.validAt) {
        _setTimelock(pendingTimelock.value);
    }

    /// @inheritdoc IMetaMorphoBase
    function acceptGuardian() external afterTimelock(pendingGuardian.validAt) {
        _setGuardian(pendingGuardian.value);
    }

    /// @inheritdoc IMetaMorphoBase
    function acceptCap(MarketParams memory marketParams)
        external
        afterTimelock(pendingCap[marketParams.id()].validAt)
    {
        Id id = marketParams.id();

        // Safe "unchecked" cast because pendingCap <= type(uint184).max.
        _setCap(marketParams, id, uint184(pendingCap[id].value));
    }

    /// @inheritdoc IMetaMorphoBase
    function skim(address token) external {
        if (skimRecipient == address(0)) revert ErrorsLib.ZeroAddress();

        uint256 amount = IERC20(token).balanceOf(address(this));

        IERC20(token).safeTransfer(skimRecipient, amount);

        emit EventsLib.Skim(_msgSender(), token, amount);
    }

    /* ERC4626 (PUBLIC) */

    /// @inheritdoc IERC20Metadata
    function decimals() public view override(ERC20, ERC4626) returns (uint8) {
        return ERC4626.decimals();
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be higher than the actual max deposit due to duplicate markets in the supplyQueue.
    function maxDeposit(address) public view override returns (uint256) {
        return _maxDeposit();
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be higher than the actual max mint due to duplicate markets in the supplyQueue.
    function maxMint(address) public view override returns (uint256) {
        uint256 suppliable = _maxDeposit();

        return _convertToShares(suppliable, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be lower than the actual amount of assets that can be withdrawn by `owner` due to conversion
    /// roundings between shares and assets.
    function maxWithdraw(address owner) public view override returns (uint256 assets) {
        (assets,,) = _maxWithdraw(owner);
    }

    /// @inheritdoc IERC4626
    /// @dev Warning: May be lower than the actual amount of shares that can be redeemed by `owner` due to conversion
    /// roundings between shares and assets.
    function maxRedeem(address owner) public view override returns (uint256) {
        (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets) = _maxWithdraw(owner);

        return _convertToSharesWithTotals(assets, newTotalSupply, newTotalAssets, Math.Rounding.Floor);
    }

    /// @inheritdoc IERC4626
    /// @notice For tokens with 18 decimals, the protection against the inflation front-running attack is low. To
    /// protect against this attack, vault deployers should make an initial deposit of a non-trivial amount in the vault
    /// or depositors should check that the share price does not exceed a certain limit.
    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        // Update `lastTotalAssets` to avoid an inconsistent state in a re-entrant context.
        // It is updated again in `_deposit`.
        lastTotalAssets = newTotalAssets;

        shares = _convertToSharesWithTotals(assets, totalSupply(), newTotalAssets, Math.Rounding.Floor);

        _deposit(_msgSender(), receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        // Update `lastTotalAssets` to avoid an inconsistent state in a re-entrant context.
        // It is updated again in `_deposit`.
        lastTotalAssets = newTotalAssets;

        assets = _convertToAssetsWithTotals(shares, totalSupply(), newTotalAssets, Math.Rounding.Ceil);

        _deposit(_msgSender(), receiver, assets, shares);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxWithdraw` and optimistically withdraw assets.

        shares = _convertToSharesWithTotals(assets, totalSupply(), newTotalAssets, Math.Rounding.Ceil);

        // `newTotalAssets - assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(newTotalAssets.zeroFloorSub(assets));

        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxRedeem` and optimistically redeem shares.

        assets = _convertToAssetsWithTotals(shares, totalSupply(), newTotalAssets, Math.Rounding.Floor);

        // `newTotalAssets - assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(newTotalAssets.zeroFloorSub(assets));

        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view override returns (uint256 assets) {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            assets += MORPHO.expectedSupplyAssets(_marketParams(withdrawQueue[i]), address(this));
        }
    }

    /* ERC4626 (INTERNAL) */

    /// @inheritdoc ERC4626
    function _decimalsOffset() internal view override returns (uint8) {
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

        assets = _convertToAssetsWithTotals(balanceOf(owner), newTotalSupply, newTotalAssets, Math.Rounding.Floor);
        assets -= _simulateWithdrawMorpho(assets);
    }

    /// @dev Returns the maximum amount of assets that the vault can supply on Morpho.
    function _maxDeposit() internal view returns (uint256 totalSuppliable) {
        for (uint256 i; i < supplyQueue.length; ++i) {
            Id id = supplyQueue[i];

            uint256 supplyCap = config[id].cap;
            if (supplyCap == 0) continue;

            uint256 supplyShares = MORPHO.supplyShares(id, address(this));
            (uint256 totalSupplyAssets, uint256 totalSupplyShares,,) = MORPHO.expectedMarketBalances(_marketParams(id));
            // `supplyAssets` needs to be rounded up for `totalSuppliable` to be rounded down.
            uint256 supplyAssets = supplyShares.toAssetsUp(totalSupplyAssets, totalSupplyShares);

            totalSuppliable += supplyCap.zeroFloorSub(supplyAssets);
        }
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
    ) internal view returns (uint256) {
        return assets.mulDiv(newTotalSupply + 10 ** _decimalsOffset(), newTotalAssets + 1, rounding);
    }

    /// @dev Returns the amount of assets that the vault would exchange for the amount of `shares` provided.
    /// @dev It assumes that the arguments `newTotalSupply` and `newTotalAssets` are up to date.
    function _convertToAssetsWithTotals(
        uint256 shares,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal view returns (uint256) {
        return shares.mulDiv(newTotalAssets + 1, newTotalSupply + 10 ** _decimalsOffset(), rounding);
    }

    /// @inheritdoc ERC4626
    /// @dev Used in mint or deposit to deposit the underlying asset to Morpho markets.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares);

        _supplyMorpho(assets);

        // `lastTotalAssets + assets` may be a little off from `totalAssets()`.
        _updateLastTotalAssets(lastTotalAssets + assets);
    }

    /// @inheritdoc ERC4626
    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Morpho markets.
    /// @dev Depending on 3 cases, reverts when withdrawing "too much" with:
    /// 1. NotEnoughLiquidity when withdrawing more than available liquidity.
    /// 2. ERC20InsufficientAllowance when withdrawing more than `caller`'s allowance.
    /// 3. ERC20InsufficientBalance when withdrawing more than `owner`'s balance.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        _withdrawMorpho(assets);

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /* INTERNAL */

    /// @dev Returns the market params of the market defined by `id`.
    function _marketParams(Id id) internal view returns (MarketParams memory) {
        return MORPHO.idToMarketParams(id);
    }

    /// @dev Accrues interest on Morpho Blue and returns the vault's assets & corresponding shares supplied on the
    /// market defined by `marketParams`, as well as the market's state.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _accruedSupplyBalance(MarketParams memory marketParams, Id id)
        internal
        returns (uint256 assets, uint256 shares, Market memory market)
    {
        MORPHO.accrueInterest(marketParams);

        market = MORPHO.market(id);
        shares = MORPHO.supplyShares(id, address(this));
        assets = shares.toAssetsDown(market.totalSupplyAssets, market.totalSupplyShares);
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
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _setCap(MarketParams memory marketParams, Id id, uint184 supplyCap) internal {
        MarketConfig storage marketConfig = config[id];

        if (supplyCap > 0) {
            if (!marketConfig.enabled) {
                withdrawQueue.push(id);

                if (withdrawQueue.length > ConstantsLib.MAX_QUEUE_LENGTH) revert ErrorsLib.MaxQueueLengthExceeded();

                marketConfig.enabled = true;

                // Take into account assets of the new market without applying a fee.
                _updateLastTotalAssets(lastTotalAssets + MORPHO.expectedSupplyAssets(marketParams, address(this)));

                emit EventsLib.SetWithdrawQueue(msg.sender, withdrawQueue);
            }

            marketConfig.removableAt = 0;
        }

        marketConfig.cap = supplyCap;

        emit EventsLib.SetCap(_msgSender(), id, supplyCap);

        delete pendingCap[id];
    }

    /* LIQUIDITY ALLOCATION */

    /// @dev Supplies `assets` to Morpho.
    function _supplyMorpho(uint256 assets) internal {
        for (uint256 i; i < supplyQueue.length; ++i) {
            Id id = supplyQueue[i];

            uint256 supplyCap = config[id].cap;
            if (supplyCap == 0) continue;

            MarketParams memory marketParams = _marketParams(id);

            MORPHO.accrueInterest(marketParams);

            Market memory market = MORPHO.market(id);
            uint256 supplyShares = MORPHO.supplyShares(id, address(this));
            // `supplyAssets` needs to be rounded up for `toSupply` to be rounded down.
            uint256 supplyAssets = supplyShares.toAssetsUp(market.totalSupplyAssets, market.totalSupplyShares);

            uint256 toSupply = UtilsLib.min(supplyCap.zeroFloorSub(supplyAssets), assets);

            if (toSupply > 0) {
                // Using try/catch to skip markets that revert.
                try MORPHO.supply(marketParams, toSupply, 0, address(this), hex"") {
                    assets -= toSupply;
                } catch {}
            }

            if (assets == 0) return;
        }

        if (assets != 0) revert ErrorsLib.AllCapsReached();
    }

    /// @dev Withdraws `assets` from Morpho.
    function _withdrawMorpho(uint256 assets) internal {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            Id id = withdrawQueue[i];
            MarketParams memory marketParams = _marketParams(id);
            (uint256 supplyAssets,, Market memory market) = _accruedSupplyBalance(marketParams, id);

            uint256 toWithdraw = UtilsLib.min(
                _withdrawable(marketParams, market.totalSupplyAssets, market.totalBorrowAssets, supplyAssets), assets
            );

            if (toWithdraw > 0) {
                // Using try/catch to skip markets that revert.
                try MORPHO.withdraw(marketParams, toWithdraw, 0, address(this), address(this)) {
                    assets -= toWithdraw;
                } catch {}
            }

            if (assets == 0) return;
        }

        if (assets != 0) revert ErrorsLib.NotEnoughLiquidity();
    }

    /// @dev Simulates a withdraw of `assets` from Morpho.
    /// @return The remaining assets to be withdrawn.
    function _simulateWithdrawMorpho(uint256 assets) internal view returns (uint256) {
        for (uint256 i; i < withdrawQueue.length; ++i) {
            Id id = withdrawQueue[i];
            MarketParams memory marketParams = _marketParams(id);

            uint256 supplyShares = MORPHO.supplyShares(id, address(this));
            (uint256 totalSupplyAssets, uint256 totalSupplyShares, uint256 totalBorrowAssets,) =
                MORPHO.expectedMarketBalances(marketParams);

            // The vault withdrawing from Morpho cannot fail because:
            // 1. oracle.price() is never called (the vault doesn't borrow)
            // 2. the amount is capped to the liquidity available on Morpho
            // 3. virtually accruing interest didn't fail
            assets = assets.zeroFloorSub(
                _withdrawable(
                    marketParams,
                    totalSupplyAssets,
                    totalBorrowAssets,
                    supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares)
                )
            );

            if (assets == 0) break;
        }

        return assets;
    }

    /// @dev Returns the withdrawable amount of assets from the market defined by `marketParams`, given the market's
    /// total supply and borrow assets and the vault's assets supplied.
    function _withdrawable(
        MarketParams memory marketParams,
        uint256 totalSupplyAssets,
        uint256 totalBorrowAssets,
        uint256 supplyAssets
    ) internal view returns (uint256) {
        // Inside a flashloan callback, liquidity on Morpho Blue may be limited to the singleton's balance.
        uint256 availableLiquidity = UtilsLib.min(
            totalSupplyAssets - totalBorrowAssets, ERC20(marketParams.loanToken).balanceOf(address(MORPHO))
        );

        return UtilsLib.min(supplyAssets, availableLiquidity);
    }

    /* FEE MANAGEMENT */

    /// @dev Updates `lastTotalAssets` to `updatedTotalAssets`.
    function _updateLastTotalAssets(uint256 updatedTotalAssets) internal {
        lastTotalAssets = updatedTotalAssets;

        emit EventsLib.UpdateLastTotalAssets(updatedTotalAssets);
    }

    /// @dev Accrues the fee and mints the fee shares to the fee recipient.
    /// @return newTotalAssets The vaults total assets after accruing the interest.
    function _accrueFee() internal returns (uint256 newTotalAssets) {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares();

        if (feeShares != 0) _mint(feeRecipient, feeShares);

        emit EventsLib.AccrueInterest(newTotalAssets, feeShares);
    }

    /// @dev Computes and returns the fee shares (`feeShares`) to mint and the new vault's total assets
    /// (`newTotalAssets`).
    function _accruedFeeShares() internal view returns (uint256 feeShares, uint256 newTotalAssets) {
        newTotalAssets = totalAssets();

        uint256 totalInterest = newTotalAssets.zeroFloorSub(lastTotalAssets);
        if (totalInterest != 0 && fee != 0) {
            // It is acknowledged that `feeAssets` may be rounded down to 0 if `totalInterest * fee < WAD`.
            uint256 feeAssets = totalInterest.mulDiv(fee, WAD);
            // The fee assets is subtracted from the total assets in this calculation to compensate for the fact
            // that total assets is already increased by the total interest (including the fee assets).
            feeShares =
                _convertToSharesWithTotals(feeAssets, totalSupply(), newTotalAssets - feeAssets, Math.Rounding.Floor);
        }
    }
}
