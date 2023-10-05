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
import {ERC20Votes} from "@openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import {IERC20Metadata, ERC20Permit} from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20, IERC4626, ERC20, ERC4626, Math, SafeERC20} from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

contract MetaMorpho is ERC4626, ERC20Permit, ERC20Votes, Ownable2Step, Multicall, IMetaMorpho {
    using Math for uint256;
    using UtilsLib for uint256;
    using SafeCast for uint256;
    using MorphoLib for IMorpho;
    using SharesMathLib for uint256;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    /* IMMUTABLES */

    IMorpho public immutable MORPHO;

    /* STORAGE */

    address public riskManager;
    mapping(address => bool) internal _isAllocator;

    mapping(Id => MarketConfig) public config;
    mapping(Id => PendingUint192) public pendingCap;

    /// @dev Stores the order of markets on which liquidity is supplied upon deposit.
    /// @dev Can contain any market. A market is skipped as soon as its supply cap is reached.
    Id[] public supplyQueue;

    /// @dev Stores the order of markets from which liquidity is withdrawn upon withdrawal.
    /// @dev Always contain all non-zero cap markets as well as all markets on which the vault supplies liquidity,
    /// without duplicate.
    Id[] public withdrawQueue;

    PendingUint192 public pendingFee;
    PendingUint192 public pendingTimelock;
    PendingAddress public pendingGuardian;

    uint96 public fee;
    address public feeRecipient;

    uint256 public timelock;
    address public guardian;

    address public rewardsDistributor;

    /// @dev Stores the total assets owned by this vault when the fee was last accrued.
    uint256 public lastTotalAssets;
    uint256 public idle;

    /* CONSTRUCTOR */

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

    modifier onlyRiskManager() {
        require(_msgSender() == riskManager || _msgSender() == owner(), ErrorsLib.NOT_RISK_MANAGER);

        _;
    }

    modifier onlyGuardian() {
        require(_msgSender() == guardian, ErrorsLib.NOT_GUARDIAN);

        _;
    }

    modifier onlyAllocator() {
        require(isAllocator(_msgSender()), ErrorsLib.NOT_ALLOCATOR);

        _;
    }

    modifier timelockElapsed(uint256 submittedAt) {
        require(submittedAt != 0, ErrorsLib.NO_PENDING_VALUE);
        require(block.timestamp >= submittedAt + timelock, ErrorsLib.TIMELOCK_NOT_ELAPSED);
        require(block.timestamp <= submittedAt + timelock + TIMELOCK_EXPIRATION, ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED);

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    function setRiskManager(address newRiskManager) external onlyOwner {
        require(newRiskManager != riskManager, ErrorsLib.ALREADY_SET);

        riskManager = newRiskManager;

        emit EventsLib.SetRiskManager(newRiskManager);
    }

    function setIsAllocator(address newAllocator, bool newIsAllocator) external onlyOwner {
        require(_isAllocator[newAllocator] != newIsAllocator, ErrorsLib.ALREADY_SET);

        _isAllocator[newAllocator] = newIsAllocator;

        emit EventsLib.SetIsAllocator(newAllocator, newIsAllocator);
    }

    function setRewardsDistributor(address newRewardsDistributor) external onlyOwner {
        require(newRewardsDistributor != rewardsDistributor, ErrorsLib.ALREADY_SET);

        rewardsDistributor = newRewardsDistributor;

        emit EventsLib.SetRewardsDistributor(newRewardsDistributor);
    }

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

    function acceptTimelock() external timelockElapsed(pendingTimelock.submittedAt) onlyOwner {
        _setTimelock(pendingTimelock.value);
    }

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

    function acceptFee() external timelockElapsed(pendingFee.submittedAt) onlyOwner {
        _setFee(pendingFee.value);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET);
        require(newFeeRecipient != address(0) || fee == 0, ErrorsLib.ZERO_FEE_RECIPIENT);

        // Accrue interest to the previous fee recipient set before changing it.
        _updateLastTotalAssets(_accrueFee());

        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

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

    function acceptGuardian() external timelockElapsed(pendingGuardian.submittedAt) onlyOwner {
        _setGuardian(pendingGuardian.value);
    }

    /* ONLY RISK MANAGER FUNCTIONS */

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

    function acceptCap(Id id) external timelockElapsed(pendingCap[id].submittedAt) onlyRiskManager {
        _setCap(id, pendingCap[id].value);
    }

    /* ONLY ALLOCATOR FUNCTIONS */

    /// @dev The supply queue can be set containing duplicate markets, but it would only increase the cost of depositing
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

    function transferRewards(address token) external {
        require(rewardsDistributor != address(0), ErrorsLib.ZERO_ADDRESS);

        uint256 amount = IERC20(token).balanceOf(address(this));
        if (token == asset()) amount -= idle;

        SafeERC20.safeTransfer(IERC20(token), rewardsDistributor, amount);

        emit EventsLib.TransferRewards(msg.sender, rewardsDistributor, token, amount);
    }

    /* ONLY GUARDIAN FUNCTIONS */

    function revokeTimelock() external onlyGuardian {
        emit EventsLib.RevokeTimelock(msg.sender, pendingTimelock);

        delete pendingTimelock;
    }

    function revokeCap(Id id) external onlyGuardian {
        emit EventsLib.RevokeCap(msg.sender, id, pendingCap[id]);

        delete pendingCap[id];
    }

    function revokeGuardian() external onlyGuardian {
        emit EventsLib.RevokeGuardian(msg.sender, pendingGuardian);

        delete pendingGuardian;
    }

    /* PUBLIC */

    function isAllocator(address target) public view returns (bool) {
        return _isAllocator[target] || target == riskManager || target == owner();
    }

    /* ERC4626 (PUBLIC) */

    function decimals() public view override(IERC20Metadata, ERC20, ERC4626) returns (uint8) {
        return ERC4626.decimals();
    }

    function maxWithdraw(address owner) public view override(IERC4626, ERC4626) returns (uint256 assets) {
        (assets,,) = _maxWithdraw(owner);
    }

    function maxRedeem(address owner) public view override(IERC4626, ERC4626) returns (uint256) {
        (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets) = _maxWithdraw(owner);

        return _convertToSharesWithFeeAccrued(assets, newTotalSupply, newTotalAssets, Math.Rounding.Down);
    }

    function deposit(uint256 assets, address receiver) public override(IERC4626, ERC4626) returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        shares = _convertToSharesWithFeeAccrued(assets, totalSupply(), newTotalAssets, Math.Rounding.Down);
        _deposit(_msgSender(), receiver, assets, shares);

        _updateLastTotalAssets(newTotalAssets + assets);
    }

    function mint(uint256 shares, address receiver) public override(IERC4626, ERC4626) returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        assets = _convertToAssetsWithFeeAccrued(shares, totalSupply(), newTotalAssets, Math.Rounding.Up);
        _deposit(_msgSender(), receiver, assets, shares);

        _updateLastTotalAssets(newTotalAssets + assets);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(IERC4626, ERC4626)
        returns (uint256 shares)
    {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxWithdraw` and optimistically withdraw assets.

        shares = _convertToSharesWithFeeAccrued(assets, totalSupply(), newTotalAssets, Math.Rounding.Up);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        _updateLastTotalAssets(newTotalAssets - assets);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override(IERC4626, ERC4626)
        returns (uint256 assets)
    {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxRedeem` and optimistically redeem shares.

        assets = _convertToAssetsWithFeeAccrued(shares, totalSupply(), newTotalAssets, Math.Rounding.Down);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        _updateLastTotalAssets(newTotalAssets - assets);
    }

    function totalAssets() public view override(IERC4626, ERC4626) returns (uint256 assets) {
        uint256 nbMarkets = withdrawQueue.length;

        for (uint256 i; i < nbMarkets; ++i) {
            assets += _supplyBalance(_marketParams(withdrawQueue[i]));
        }

        assets += idle;
    }

    /* ERC20Votes (INTERNAL) */

    function _mint(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        ERC20Votes._mint(account, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        ERC20Votes._burn(account, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        ERC20Votes._afterTokenTransfer(from, to, amount);
    }

    /* ERC4626 (INTERNAL) */

    function _decimalsOffset() internal pure override returns (uint8) {
        return DECIMALS_OFFSET;
    }

    function _maxWithdraw(address owner)
        internal
        view
        returns (uint256 assets, uint256 newTotalSupply, uint256 newTotalAssets)
    {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares();
        newTotalSupply = totalSupply() + feeShares;

        assets = _convertToAssetsWithFeeAccrued(balanceOf(owner), newTotalSupply, newTotalAssets, Math.Rounding.Down);
        assets -= _staticWithdrawMorpho(assets);
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToSharesWithFeeAccrued(assets, totalSupply() + feeShares, newTotalAssets, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return _convertToAssetsWithFeeAccrued(shares, totalSupply() + feeShares, newTotalAssets, rounding);
    }

    function _convertToSharesWithFeeAccrued(
        uint256 assets,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal pure returns (uint256) {
        return assets.mulDiv(newTotalSupply + 10 ** _decimalsOffset(), newTotalAssets + 1, rounding);
    }

    function _convertToAssetsWithFeeAccrued(
        uint256 shares,
        uint256 newTotalSupply,
        uint256 newTotalAssets,
        Math.Rounding rounding
    ) internal pure returns (uint256) {
        return shares.mulDiv(newTotalAssets + 1, newTotalSupply + 10 ** _decimalsOffset(), rounding);
    }

    /// @dev Used in mint or deposit to deposit the underlying asset to Blue markets.
    function _deposit(address caller, address owner, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, owner, assets, shares);

        _supplyMorpho(assets);
    }

    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Blue markets.
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

    function _marketParams(Id id) internal view returns (MarketParams memory) {
        return IMorphoMarketParams(address(MORPHO)).idToMarketParams(id);
    }

    function _supplyBalance(MarketParams memory marketParams) internal view returns (uint256) {
        return MORPHO.expectedSupplyBalance(marketParams, address(this));
    }

    function _setTimelock(uint256 newTimelock) internal {
        timelock = newTimelock;

        emit EventsLib.SetTimelock(newTimelock);

        delete pendingTimelock;
    }

    function _setGuardian(address newGuardian) internal {
        guardian = newGuardian;

        emit EventsLib.SetGuardian(newGuardian);

        delete pendingGuardian;
    }

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

    function _setFee(uint256 newFee) internal {
        require(newFee == 0 || feeRecipient != address(0), ErrorsLib.ZERO_FEE_RECIPIENT);

        // Accrue interest using the previous fee set before changing it.
        _updateLastTotalAssets(_accrueFee());

        // Safe "unchecked" cast because newFee <= MAX_FEE.
        fee = uint96(newFee);

        emit EventsLib.SetFee(newFee);

        delete pendingFee;
    }

    /* LIQUIDITY ALLOCATION */

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

    /// @dev Withdraws `assets` from the idle liquidity and Morpho.
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

    /// @dev Fakes a withdraw of `assets` from the idle liquidity and Morpho.
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

    function _withdrawIdle(uint256 assets) internal view returns (uint256, uint256) {
        return (assets.zeroFloorSub(idle), idle.zeroFloorSub(assets));
    }

    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _suppliable(MarketParams memory marketParams, Id id) internal view returns (uint256) {
        uint256 marketCap = config[id].cap;
        if (marketCap == 0) return 0;

        return marketCap.zeroFloorSub(_supplyBalance(marketParams));
    }

    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _withdrawable(MarketParams memory marketParams, Id id) internal view returns (uint256) {
        uint256 supplyShares = MORPHO.supplyShares(id, address(this));
        (uint256 totalSupplyAssets, uint256 totalSupplyShares, uint256 totalBorrowAssets,) =
            MORPHO.expectedMarketBalances(marketParams);
        uint256 availableLiquidity = totalSupplyAssets - totalBorrowAssets;

        return UtilsLib.min(supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares), availableLiquidity);
    }

    /* FEE MANAGEMENT */

    function _updateLastTotalAssets(uint256 newTotalAssets) internal {
        lastTotalAssets = newTotalAssets;

        emit EventsLib.UpdateLastTotalAssets(newTotalAssets);
    }

    function _accrueFee() internal returns (uint256 newTotalAssets) {
        uint256 feeShares;
        (feeShares, newTotalAssets) = _accruedFeeShares();

        if (feeShares != 0 && feeRecipient != address(0)) _mint(feeRecipient, feeShares);
    }

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
