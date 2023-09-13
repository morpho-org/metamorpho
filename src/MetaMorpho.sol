// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IMorphoMarketParams} from "./interfaces/IMorphoMarketParams.sol";
import {MarketAllocation, Pending, IMetaMorpho} from "./interfaces/IMetaMorpho.sol";
import {Id, MarketParams, Market, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import "src/libraries/ConstantsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {WAD} from "@morpho-blue/libraries/MathLib.sol";
import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";
import {VaultMarket, ConfigSet, ConfigSetLib} from "./libraries/ConfigSetLib.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";

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
    using ConfigSetLib for ConfigSet;
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;

    /* IMMUTABMES */

    IMorpho internal immutable MORPHO;

    /* STORAGE */

    mapping(address => bool) public isRiskManager;
    mapping(address => bool) public isAllocator;
    mapping(Id => Pending) public pendingMarket;

    Id[] public supplyAllocationOrder;
    Id[] public withdrawAllocationOrder;

    Pending public pendingFee;
    uint96 public fee;
    address feeRecipient;

    Pending public pendingTimelock;
    uint256 public timelock;

    /// @dev Stores the total assets owned by this vault when the fee was last accrued.
    uint256 lastTotalAssets;

    ConfigSet private _config;

    /* CONSTRUCTOR */

    constructor(address morpho, uint256 initialTimelock, IERC20 _asset, string memory _name, string memory _symbol)
        ERC4626(_asset)
        ERC20(_name, _symbol)
    {
        require(initialTimelock <= MAX_TIMELOCK, ErrorsLib.MAX_TIMELOCK_EXCEEDED);

        MORPHO = IMorpho(morpho);
        timelock = initialTimelock;

        SafeERC20.safeApprove(_asset, morpho, type(uint256).max);
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

    modifier timelockElapsed(uint128 timestamp) {
        require(block.timestamp >= timestamp + timelock, ErrorsLib.TIMELOCK_NOT_ELAPSED);
        require(block.timestamp <= timestamp + timelock + TIMELOCK_EXPIRATION, ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED);

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    function submitTimelock(uint256 newTimelock) external onlyOwner {
        require(newTimelock <= MAX_TIMELOCK, ErrorsLib.MAX_TIMELOCK_EXCEEDED);

        // Safe "unchecked" cast because newTimelock <= MAX_TIMELOCK.
        pendingTimelock = Pending(uint128(newTimelock), uint128(block.timestamp));

        emit EventsLib.SubmitTimelock(newTimelock);
    }

    function acceptTimelock() external timelockElapsed(pendingTimelock.timestamp) onlyOwner {
        timelock = pendingTimelock.value;

        emit EventsLib.AcceptTimelock(pendingTimelock.value);

        delete pendingTimelock;
    }

    function setIsRiskManager(address newRiskManager, bool newIsRiskManager) external onlyOwner {
        isRiskManager[newRiskManager] = newIsRiskManager;

        emit EventsLib.SetIsRiskManager(newRiskManager, newIsRiskManager);
    }

    function setIsAllocator(address newAllocator, bool newIsAllocator) external onlyOwner {
        isAllocator[newAllocator] = newIsAllocator;

        emit EventsLib.SetIsAllocator(newAllocator, newIsAllocator);
    }

    function submitFee(uint256 newFee) external onlyOwner {
        require(newFee != fee, ErrorsLib.ALREADY_SET);
        require(newFee <= WAD, ErrorsLib.MAX_FEE_EXCEEDED);

        // Safe "unchecked" cast because newFee <= WAD.
        pendingFee = Pending(uint128(newFee), uint128(block.timestamp));

        emit EventsLib.SubmitFee(newFee);
    }

    function acceptFee() external timelockElapsed(pendingFee.timestamp) onlyOwner {
        // Accrue interest using the previous fee set before changing it.
        _updateLastTotalAssets(_accrueFee());

        fee = uint96(pendingFee.value);

        emit EventsLib.AcceptFee(pendingFee.value);

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

    function submitMarket(MarketParams memory marketParams, uint128 cap) external onlyRiskManager {
        require(marketParams.borrowableToken == asset(), ErrorsLib.INCONSISTENT_ASSET);
        (,,,, uint128 lastUpdate,) = MORPHO.market(marketParams.id());
        require(lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        Id id = marketParams.id();
        require(!_config.contains(id));

        pendingMarket[id] = Pending(cap, uint128(block.timestamp));

        emit EventsLib.SubmitMarket(id);
    }

    function enableMarket(Id id) external timelockElapsed(pendingMarket[id].timestamp) onlyRiskManager {
        supplyAllocationOrder.push(id);
        withdrawAllocationOrder.push(id);

        MarketParams memory marketParams = IMorphoMarketParams(address(MORPHO)).idToMarketParams(id);
        uint128 cap = pendingMarket[id].value;

        require(_config.update(marketParams, uint256(cap)), ErrorsLib.ENABLE_MARKET_FAILED);

        emit EventsLib.EnableMarket(id, cap);
    }

    function setCap(MarketParams memory marketParams, uint128 cap) external onlyRiskManager {
        require(_config.contains(marketParams.id()), ErrorsLib.MARKET_NOT_ENABLED);

        _config.update(marketParams, cap);

        emit EventsLib.SetCap(cap);
    }

    function disableMarket(Id id) external onlyRiskManager {
        _removeFromAllocationOrder(supplyAllocationOrder, id);
        _removeFromAllocationOrder(withdrawAllocationOrder, id);

        require(_config.remove(id), ErrorsLib.DISABLE_MARKET_FAILED);

        emit EventsLib.DisableMarket(id);
    }

    /* ONLY ALLOCATOR FUNCTIONS */

    function setSupplyAllocationOrder(Id[] calldata newSupplyAllocationOrder) external onlyAllocator {
        _checkAllocationOrder(supplyAllocationOrder, newSupplyAllocationOrder);

        supplyAllocationOrder = newSupplyAllocationOrder;
    }

    function setWithdrawAllocationOrder(Id[] calldata newWithdrawAllocationOrder) external onlyAllocator {
        _checkAllocationOrder(withdrawAllocationOrder, newWithdrawAllocationOrder);

        withdrawAllocationOrder = newWithdrawAllocationOrder;
    }

    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied)
        external
        onlyAllocator
    {
        _reallocate(withdrawn, supplied);
    }

    /* PUBLIC */

    function marketCap(Id id) public view returns (uint256) {
        return _market(id).cap;
    }

    /* ERC4626 */

    function maxWithdraw(address owner) public view override returns (uint256) {
        _accruedFeeShares();

        return _staticWithdrawOrder(super.maxWithdraw(owner));
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
        uint256 nbMarkets = _config.length();

        for (uint256 i; i < nbMarkets; ++i) {
            MarketParams memory marketParams = _config.at(i);

            assets += _supplyBalance(marketParams);
        }

        assets += ERC20(asset()).balanceOf(address(this));
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

        require(_depositOrder(assets) == 0, ErrorsLib.DEPOSIT_ORDER_FAILED);

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

        require(_withdrawOrder(assets) == 0, ErrorsLib.WITHDRAW_ORDER_FAILED);

        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
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

    /* INTERNAL */

    function _market(Id id) internal view returns (VaultMarket storage) {
        require(_config.contains(id), ErrorsLib.UNAUTHORIZED_MARKET);

        return _config.getMarket(id);
    }

    function _supplyBalance(MarketParams memory marketParams) internal view returns (uint256) {
        return MORPHO.expectedSupplyBalance(marketParams, address(this));
    }

    function _supplyMorpho(MarketAllocation memory allocation) internal {
        Id id = allocation.marketParams.id();

        uint256 cap = marketCap(id);
        if (cap > 0) {
            uint256 newSupply = allocation.assets + _supplyBalance(allocation.marketParams);

            require(newSupply <= cap, ErrorsLib.SUPPLY_CAP_EXCEEDED);
        }

        MORPHO.supply(allocation.marketParams, allocation.assets, 0, address(this), hex"");
    }

    function _reallocate(MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) internal {
        uint256 nbWithdrawn = withdrawn.length;

        for (uint256 i; i < nbWithdrawn; ++i) {
            MarketAllocation memory allocation = withdrawn[i];

            MORPHO.withdraw(allocation.marketParams, allocation.assets, 0, address(this), address(this));
        }

        uint256 nbSupplied = supplied.length;

        for (uint256 i; i < nbSupplied; ++i) {
            _supplyMorpho(supplied[i]); // TODO: should we check config if supplied is provided by an onchain strategy?
        }
    }

    /// @dev MUST NOT revert on a market.
    function _depositOrder(uint256 assets) internal returns (uint256) {
        uint256 length = supplyAllocationOrder.length;

        for (uint256 i; i < length; ++i) {
            Id id = supplyAllocationOrder[i];

            MarketParams memory marketParams = _config.at(_config.getMarket(id).rank - 1);
            uint256 cap = marketCap(id);
            uint256 toDeposit = assets;

            if (cap > 0) {
                uint256 currentSupply = _supplyBalance(marketParams);

                toDeposit = UtilsLib.min(cap.zeroFloorSub(currentSupply), assets);
            }

            if (toDeposit > 0) {
                bytes memory encodedCall =
                    abi.encodeCall(MORPHO.supply, (marketParams, toDeposit, 0, address(this), hex""));
                (bool success,) = address(MORPHO).call(encodedCall);

                if (success) assets -= toDeposit;
            }

            if (assets == 0) break;
        }

        return assets;
    }

    /// @dev MUST NOT revert on a market.
    function _staticWithdrawOrder(uint256 assets) internal view returns (uint256) {
        uint256 length = withdrawAllocationOrder.length;

        for (uint256 i; i < length; ++i) {
            (MarketParams memory marketParams, uint256 toWithdraw) = _withdrawable(assets, withdrawAllocationOrder[i]);

            if (toWithdraw > 0) {
                bytes memory encodedCall =
                    abi.encodeCall(MORPHO.withdraw, (marketParams, toWithdraw, 0, address(this), address(this)));
                (bool success,) = address(MORPHO).staticcall(encodedCall);

                if (success) assets -= toWithdraw;
            }

            if (assets == 0) break;
        }

        return assets;
    }

    /// @dev MUST NOT revert on a market.
    function _withdrawOrder(uint256 assets) internal returns (uint256) {
        uint256 length = withdrawAllocationOrder.length;

        for (uint256 i; i < length; ++i) {
            (MarketParams memory marketParams, uint256 toWithdraw) = _withdrawable(assets, withdrawAllocationOrder[i]);

            if (toWithdraw > 0) {
                bytes memory encodedCall =
                    abi.encodeCall(MORPHO.withdraw, (marketParams, toWithdraw, 0, address(this), address(this)));
                (bool success,) = address(MORPHO).call(encodedCall);

                if (success) assets -= toWithdraw;
            }

            if (assets == 0) break;
        }

        return assets;
    }

    function _withdrawable(uint256 assets, Id id)
        internal
        view
        returns (MarketParams memory marketParams, uint256 withdrawable)
    {
        marketParams = _config.at(_config.getMarket(id).rank - 1);
        (uint256 totalSupply,, uint256 totalBorrow,) = MORPHO.expectedMarketBalances(marketParams);
        uint256 available = totalSupply - totalBorrow;
        withdrawable = UtilsLib.min(available, assets);
    }

    function _removeFromAllocationOrder(Id[] storage order, Id id) internal {
        uint256 length = _config.length();

        for (uint256 i; i < length; ++i) {
            // Do not conserve the previous order.
            if (Id.unwrap(order[i]) == Id.unwrap(id)) {
                order[i] = order[length - 1];
                order.pop();

                return;
            }
        }
    }

    function _checkAllocationOrder(Id[] storage oldOrder, Id[] calldata newOrder) internal view {
        uint256 length = newOrder.length;

        require(length == oldOrder.length, ErrorsLib.INVALID_LENGTH);

        for (uint256 i; i < length; ++i) {
            require(_config.contains(newOrder[i]), ErrorsLib.MARKET_NOT_ENABLED);
        }
    }

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

    function _decimalsOffset() internal pure override returns (uint8) {
        return 6;
    }
}
