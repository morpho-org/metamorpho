// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IMorphoMarketParams} from "./interfaces/IMorphoMarketParams.sol";
import {IMetaMorpho, PendingParameter, MarketAllocation} from "./interfaces/IMetaMorpho.sol";
import {Id, MarketParams, Market, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import "src/libraries/ConstantsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {WAD} from "@morpho-blue/libraries/MathLib.sol";
import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";
import {MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {
    IERC20,
    ERC20,
    ERC4626,
    Context,
    Math,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract MetaMorpho is ERC4626, Ownable2Step, IMetaMorpho {
    using Math for uint256;
    using UtilsLib for uint256;
    using SafeCast for uint256;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;
    using MorphoLib for IMorpho;

    /* IMMUTABMES */

    IMorpho internal immutable MORPHO;

    /* STORAGE */

    mapping(address => bool) public isRiskManager;
    mapping(address => bool) public isAllocator;

    mapping(Id => uint256) public cap;
    mapping(Id => PendingParameter) public pendingCap;

    /// @dev Stores the order of markets on which liquidity is supplied upon deposit.
    /// @dev Can contain any market. A market is skipped as soon as its supply cap is reached.
    Id[] public supplyQueue;

    /// @dev Stores the order of markets from which liquidity is withdrawn upon withdrawal.
    /// @dev Can only contain non-zero cap markets or markets on which the vault supplies liquidity.
    /// Always contains all such markets.
    Id[] public withdrawQueue;

    PendingParameter public pendingFee;
    PendingParameter public pendingTimelock;

    uint96 public fee;
    address public feeRecipient;

    uint256 public timelock;

    /// @dev Stores the total assets owned by this vault when the fee was last accrued.
    uint256 public lastTotalAssets;
    uint256 public idle;

    /* CONSTRUCTOR */

    constructor(address morpho, uint256 initialTimelock, address _asset, string memory _name, string memory _symbol)
        ERC4626(IERC20(_asset))
        ERC20(_name, _symbol)
    {
        require(initialTimelock <= MAX_TIMELOCK, ErrorsLib.MAX_TIMELOCK_EXCEEDED);

        MORPHO = IMorpho(morpho);

        _setTimelock(initialTimelock);

        SafeERC20.safeApprove(IERC20(_asset), morpho, type(uint256).max);
    }

    /* MODIFIERS */

    modifier onlyRiskManager() {
        require(isRiskManager[_msgSender()] || _msgSender() == owner(), ErrorsLib.NOT_RISK_MANAGER);

        _;
    }

    modifier onlyAllocator() {
        require(
            isAllocator[_msgSender()] || isRiskManager[_msgSender()] || _msgSender() == owner(), ErrorsLib.NOT_ALLOCATOR
        );

        _;
    }

    modifier timelockElapsed(PendingParameter memory pendingParameter) {
        uint64 submittedAt = pendingParameter.submittedAt;

        require(block.timestamp >= submittedAt + timelock, ErrorsLib.TIMELOCK_NOT_ELAPSED);
        require(block.timestamp <= submittedAt + timelock + TIMELOCK_EXPIRATION, ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED);

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    function setIsRiskManager(address newRiskManager, bool newIsRiskManager) external onlyOwner {
        isRiskManager[newRiskManager] = newIsRiskManager;

        emit EventsLib.SetIsRiskManager(newRiskManager, newIsRiskManager);
    }

    function setIsAllocator(address newAllocator, bool newIsAllocator) external onlyOwner {
        isAllocator[newAllocator] = newIsAllocator;

        emit EventsLib.SetIsAllocator(newAllocator, newIsAllocator);
    }

    function submitTimelock(uint256 newTimelock) external onlyOwner {
        require(newTimelock != timelock, ErrorsLib.ALREADY_SET);
        require(newTimelock <= MAX_TIMELOCK, ErrorsLib.MAX_TIMELOCK_EXCEEDED);

        if (timelock == 0) {
            _setTimelock(newTimelock);
        } else {
            // Safe "unchecked" cast because newTimelock <= MAX_TIMELOCK.
            pendingTimelock = PendingParameter(uint192(newTimelock), uint64(block.timestamp));

            emit EventsLib.SubmitTimelock(newTimelock);
        }
    }

    function acceptTimelock() external timelockElapsed(pendingTimelock) onlyOwner {
        _setTimelock(pendingTimelock.value);

        delete pendingTimelock;
    }

    function submitFee(uint256 newFee) external onlyOwner {
        require(newFee != fee, ErrorsLib.ALREADY_SET);
        require(newFee <= WAD, ErrorsLib.MAX_FEE_EXCEEDED);

        if (newFee == 0 || timelock == 0) {
            _setFee(newFee);
        } else {
            // Safe "unchecked" cast because newFee <= WAD.
            pendingFee = PendingParameter(uint192(newFee), uint64(block.timestamp));

            emit EventsLib.SubmitFee(newFee);
        }
    }

    function acceptFee() external timelockElapsed(pendingFee) onlyOwner {
        // Accrue interest using the previous fee set before changing it.
        _updateLastTotalAssets(_accrueFee());

        _setFee(pendingFee.value);

        delete pendingFee;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET);

        // Accrue interest to the previous fee recipient set before changing it.
        _updateLastTotalAssets(_accrueFee());

        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

    /* ONLY RISK MANAGER FUNCTIONS */

    function submitCap(MarketParams memory marketParams, uint256 marketCap) external onlyRiskManager {
        require(marketParams.borrowableToken == asset(), ErrorsLib.INCONSISTENT_ASSET);

        Id id = marketParams.id();
        require(MORPHO.lastUpdate(id) != 0, ErrorsLib.MARKET_NOT_CREATED);

        if (marketCap == 0 || timelock == 0) {
            _setCap(id, marketCap);
        } else {
            pendingCap[id] = PendingParameter(marketCap.toUint192(), uint64(block.timestamp));

            emit EventsLib.SubmitCap(id, marketCap);
        }
    }

    function acceptCap(Id id) external timelockElapsed(pendingCap[id]) onlyRiskManager {
        _setCap(id, pendingCap[id].value);

        delete pendingCap[id];
    }

    /* ONLY ALLOCATOR FUNCTIONS */

    /// @dev The supply queue can be set containing duplicate markets, but it would only increase the cost of depositing
    /// to the vault.
    function setSupplyQueue(Id[] calldata newSupplyQueue) external onlyAllocator {
        uint256 length = newSupplyQueue.length;

        for (uint256 i; i < length; ++i) {
            require(cap[newSupplyQueue[i]] > 0, ErrorsLib.UNAUTHORIZED_MARKET);
        }

        supplyQueue = newSupplyQueue;
    }

    function sortWithdrawQueue(uint256[] calldata indexes) external onlyAllocator {
        uint256 newLength = indexes.length;
        uint256 currLength = withdrawQueue.length;

        bool[] memory seen = new bool[](currLength);
        Id[] memory newWithdrawQueue = new Id[](newLength);

        for (uint256 i; i < newLength; ++i) {
            uint256 prevIndex = indexes[i];

            // If prevIndex >= currLength, reverts with native "Index out of bounds".
            require(!seen[prevIndex], ErrorsLib.DUPLICATE_MARKET);

            newWithdrawQueue[i] = withdrawQueue[prevIndex];

            seen[prevIndex] = true;
        }

        for (uint256 i; i < currLength; ++i) {
            require(seen[i] || MORPHO.supplyShares(withdrawQueue[i], address(this)) == 0, ErrorsLib.MISSING_MARKET);
        }

        withdrawQueue = newWithdrawQueue;
    }

    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied)
        external
        onlyAllocator
    {
        _reallocate(withdrawn, supplied);
    }

    /* ERC4626 (PUBLIC) */

    function maxWithdraw(address owner) public view override returns (uint256) {
        _accruedFeeShares();

        return _staticWithdrawMorpho(super.maxWithdraw(owner));
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        return _convertToShares(maxWithdraw(owner), Math.Rounding.Down);
    }

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        shares = _convertToSharesWithFeeAccrued(assets, newTotalAssets, Math.Rounding.Down);
        _deposit(_msgSender(), receiver, assets, shares);

        _updateLastTotalAssets(newTotalAssets + assets);
    }

    function mint(uint256 shares, address receiver) public override returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        assets = _convertToAssetsWithFeeAccrued(shares, newTotalAssets, Math.Rounding.Up);
        _deposit(_msgSender(), receiver, assets, shares);

        _updateLastTotalAssets(newTotalAssets + assets);
    }

    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256 shares) {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxWithdraw` and optimistically withdraw assets.

        shares = _convertToSharesWithFeeAccrued(assets, newTotalAssets, Math.Rounding.Up);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        _updateLastTotalAssets(newTotalAssets - assets);
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256 assets) {
        uint256 newTotalAssets = _accrueFee();

        // Do not call expensive `maxRedeem` and optimistically redeem shares.

        assets = _convertToAssetsWithFeeAccrued(shares, newTotalAssets, Math.Rounding.Down);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        _updateLastTotalAssets(newTotalAssets - assets);
    }

    function totalAssets() public view override returns (uint256 assets) {
        uint256 nbMarkets = withdrawQueue.length;

        for (uint256 i; i < nbMarkets; ++i) {
            assets += _supplyBalance(_marketParams(withdrawQueue[i]));
        }

        assets += idle;
    }

    /* ERC4626 (INTERNAL) */

    function _decimalsOffset() internal pure override returns (uint8) {
        return 6;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return assets.mulDiv(totalSupply() + feeShares + 10 ** _decimalsOffset(), newTotalAssets + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        (uint256 feeShares, uint256 newTotalAssets) = _accruedFeeShares();

        return shares.mulDiv(newTotalAssets + 1, totalSupply() + feeShares + 10 ** _decimalsOffset(), rounding);
    }

    function _convertToSharesWithFeeAccrued(uint256 assets, uint256 newTotalAssets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), newTotalAssets + 1, rounding);
    }

    function _convertToAssetsWithFeeAccrued(uint256 shares, uint256 newTotalAssets, Math.Rounding rounding)
        internal
        view
        returns (uint256)
    {
        return shares.mulDiv(newTotalAssets + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
    }

    /// @dev Used in mint or deposit to deposit the underlying asset to Blue markets.
    function _deposit(address caller, address owner, uint256 assets, uint256 shares) internal override {
        // If asset is ERC777, `transferFrom` can trigger a reentrancy BEFORE the transfer happens through the
        // `tokensToSend` hook. On the other hand, the `tokenReceived` hook, that is triggered after the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer before we mint so that any reentrancy would happen before the
        // assets are transferred and before the shares are minted, which is a valid state.
        // slither-disable-next-line reentrancy-no-eth
        SafeERC20.safeTransferFrom(IERC20(asset()), caller, address(this), assets);

        _supplyMorpho(assets);

        _mint(owner, shares);

        emit Deposit(caller, owner, assets, shares);
    }

    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Blue markets.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        // If asset is ERC777, `transfer` can trigger a reentrancy AFTER the transfer happens through the
        // `tokensReceived` hook. On the other hand, the `tokensToSend` hook, that is triggered before the transfer,
        // calls the vault, which is assumed not malicious.
        //
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burn(owner, shares);

        require(_withdrawMorpho(assets) == 0, ErrorsLib.WITHDRAW_FAILED_MORPHO);

        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /* INTERNAL */

    function _marketParams(Id id) internal view returns (MarketParams memory) {
        return IMorphoMarketParams(address(MORPHO)).idToMarketParams(id);
    }

    function _supplyBalance(MarketParams memory marketParams) internal view returns (uint256) {
        return MORPHO.expectedSupplyBalance(marketParams, address(this));
    }

    function _setTimelock(uint256 newTimelock) internal {
        // Safe "unchecked" cast because newTimelock <= MAX_TIMELOCK.
        timelock = newTimelock;

        emit EventsLib.SetTimelock(newTimelock);
    }

    function _setCap(Id id, uint256 marketCap) internal {
        if (marketCap > 0) {
            supplyQueue.push(id);
            withdrawQueue.push(id);

            require(withdrawQueue.length <= MAX_QUEUE_SIZE, ErrorsLib.MAX_QUEUE_SIZE_EXCEEDED);
        }

        cap[id] = marketCap;

        emit EventsLib.SetCap(id, marketCap);
    }

    function _setFee(uint256 newFee) internal {
        // Safe "unchecked" cast because newFee <= WAD.
        fee = uint96(newFee);

        emit EventsLib.SetFee(newFee);
    }

    /* LIQUIDITY ALLOCATION */

    function _reallocate(MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) internal {
        uint256 nbWithdrawn = withdrawn.length;

        for (uint256 i; i < nbWithdrawn; ++i) {
            MarketAllocation memory allocation = withdrawn[i];

            MORPHO.withdraw(allocation.marketParams, allocation.assets, 0, address(this), address(this));
        }

        uint256 nbSupplied = supplied.length;

        for (uint256 i; i < nbSupplied; ++i) {
            MarketAllocation memory allocation = supplied[i];

            require(
                _suppliable(allocation.marketParams, allocation.marketParams.id()) >= allocation.assets,
                ErrorsLib.SUPPLY_CAP_EXCEEDED
            );

            MORPHO.supply(allocation.marketParams, allocation.assets, 0, address(this), hex"");
        }
    }

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

    function _staticWithdrawMorpho(uint256 assets) internal view returns (uint256) {
        (assets,) = _withdrawIdle(assets);

        if (assets == 0) return 0;

        uint256 nbMarkets = withdrawQueue.length;

        for (uint256 i; i < nbMarkets; ++i) {
            Id id = withdrawQueue[i];
            MarketParams memory marketParams = _marketParams(id);

            uint256 toWithdraw = UtilsLib.min(_withdrawable(marketParams, id), assets);

            if (toWithdraw > 0) {
                // Don't require success to skip markets that revert.
                (bool success,) = address(MORPHO).staticcall(
                    abi.encodeCall(MORPHO.withdraw, (marketParams, toWithdraw, 0, address(this), address(this)))
                );

                if (success) assets -= toWithdraw;
            }

            if (assets == 0) return 0;
        }

        return assets;
    }

    function _withdrawIdle(uint256 assets) internal view returns (uint256, uint256) {
        return (assets.zeroFloorSub(idle), idle.zeroFloorSub(assets));
    }

    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _suppliable(MarketParams memory marketParams, Id id) internal view returns (uint256) {
        if (cap[id] == 0) return 0;

        return cap[id].zeroFloorSub(_supplyBalance(marketParams));
    }

    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _withdrawable(MarketParams memory marketParams, Id id) internal view returns (uint256) {
        uint256 supplyShares = MORPHO.supplyShares(id, address(this));
        (uint256 totalSupplyAssets, uint256 totalSupplyShares, uint256 totalBorrowAssets,) =
            MORPHO.expectedMarketBalances(marketParams);

        return UtilsLib.min(
            supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares), totalSupplyAssets - totalBorrowAssets
        );
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
