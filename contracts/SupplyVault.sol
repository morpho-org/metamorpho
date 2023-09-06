// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import {MarketAllocation, ISupplyVault} from "./interfaces/ISupplyVault.sol";
import {Id, MarketParams, Market, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

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

interface IMorphoMarketParams {
    function idToMarketParams(Id id) external returns (MarketParams memory marketParams);
}

struct Pending {
    uint128 value;
    uint128 timestamp;
}

contract SupplyVault is ERC4626, Ownable2Step, ISupplyVault {
    using Math for uint256;
    using UtilsLib for uint256;
    using ConfigSetLib for ConfigSet;
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;

    uint256 public constant TIMELOCK_EXPIRATION = 2 days;
    uint256 public constant MAX_TIMELOCK = 2 weeks;

    IMorpho internal immutable _MORPHO;

    mapping(address => bool) public isRiskManager;
    mapping(address => bool) public isAllocator;

    Id[] public supplyAllocationOrder;
    Id[] public withdrawAllocationOrder;

    mapping(Id => Pending) public pendingMarket;

    Pending public pendingFee;
    uint96 public fee;
    address feeRecipient;

    Pending public pendingTimelock;
    uint256 public timelock;

    /// @dev Stores the total assets owned by this vault when the fee was last accrued.
    uint256 lastTotalAssets;

    ConfigSet private _config;

    /* CONSTRUCTORS */

    constructor(address morpho, uint256 initialTimelock, IERC20 _asset, string memory _name, string memory _symbol)
        ERC4626(_asset)
        ERC20(_name, _symbol)
    {
        require(initialTimelock <= MAX_TIMELOCK);

        _MORPHO = IMorpho(morpho);
        timelock = initialTimelock;

        SafeERC20.safeApprove(_asset, morpho, type(uint256).max);
    }

    /* MODIFIERS */

    modifier onlyRiskManager() {
        require(isRiskManager[_msgSender()], ErrorsLib.NOT_RISK_MANAGER);

        _;
    }

    modifier onlyAllocator() {
        require(isAllocator[_msgSender()], ErrorsLib.NOT_ALLOCATOR);

        _;
    }

    modifier timelockElapsed(uint128 timestamp) {
        require(block.timestamp >= timestamp + timelock, ErrorsLib.TIMELOCK_NOT_ELAPSED);
        require(block.timestamp <= timestamp + timelock + TIMELOCK_EXPIRATION, ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED);

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    function submitPendingTimelock(uint256 newTimelock) external onlyOwner {
        require(newTimelock <= MAX_TIMELOCK, ErrorsLib.MAX_TIMELOCK_EXCEEDED);

        // Safe "unchecked" cast because newFee <= MAX_TIMELOCK.
        pendingTimelock = Pending(uint128(newTimelock), uint128(block.timestamp));
    }

    function setTimelock() external timelockElapsed(pendingTimelock.timestamp) onlyOwner {
        timelock = pendingTimelock.value;
        delete pendingTimelock;

        emit EventsLib.SetTimelock(timelock);
    }

    function setIsRiskManager(address newRiskManager, bool newIsRiskManager) external onlyOwner {
        isRiskManager[newRiskManager] = newIsRiskManager;

        emit EventsLib.SetIsRiskManager(newRiskManager, newIsRiskManager);
    }

    function setIsAllocator(address newAllocator, bool newIsAllocator) external onlyOwner {
        isAllocator[newAllocator] = newIsAllocator;

        emit EventsLib.SetIsAllocator(newAllocator, newIsAllocator);
    }

    function submitPendingFee(uint256 newFee) external onlyOwner {
        require(newFee != fee, ErrorsLib.ALREADY_SET);
        require(newFee <= WAD, ErrorsLib.MAX_FEE_EXCEEDED);

        // Safe "unchecked" cast because newFee <= WAD.
        pendingFee = Pending(uint128(newFee), uint128(block.timestamp));
    }

    function setFee() external timelockElapsed(pendingFee.timestamp) onlyOwner {
        // Accrue interest using the previous fee set before changing it.
        _accrueFee();

        fee = uint96(pendingFee.value);
        delete pendingFee;

        emit EventsLib.SetFee(fee);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != feeRecipient, ErrorsLib.ALREADY_SET);

        // Accrue interest to the previous fee recipient set before changing it.
        _accrueFee();

        feeRecipient = newFeeRecipient;

        emit EventsLib.SetFeeRecipient(newFeeRecipient);
    }

    /* ONLY RISK MANAGER FUNCTIONS */

    function submitPendingMarket(MarketParams memory marketParams, uint128 cap) external onlyRiskManager {
        require(marketParams.borrowableToken == asset(), ErrorsLib.INCONSISTENT_ASSET);
        (,,,, uint128 lastUpdate,) = _MORPHO.market(marketParams.id());
        require(lastUpdate != 0, ErrorsLib.MARKET_NOT_CREATED);
        Id id = marketParams.id();
        require(!_config.contains(id));

        pendingMarket[id] = Pending(cap, uint128(block.timestamp));
    }

    function enableMarket(Id id) external timelockElapsed(pendingMarket[id].timestamp) onlyRiskManager {
        // Add market to the ordered lists if the market is added and not just updated.
        supplyAllocationOrder.push(id);
        withdrawAllocationOrder.push(id);

        MarketParams memory marketParams = IMorphoMarketParams(address(_MORPHO)).idToMarketParams(id);

        require(_config.update(marketParams, uint256(pendingMarket[id].value)), ErrorsLib.ENABLE_MARKET_FAILED);
    }

    function setCap(MarketParams memory marketParams, uint128 cap) external onlyRiskManager {
        require(_config.contains(marketParams.id()), ErrorsLib.MARKET_NOT_ENABLED);

        _config.update(marketParams, cap);
    }

    function disableMarket(Id id) external onlyRiskManager {
        _removeFromAllocationOrder(supplyAllocationOrder, id);
        _removeFromAllocationOrder(withdrawAllocationOrder, id);

        require(_config.remove(id), ErrorsLib.DISABLE_MARKET_FAILED);
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

    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        _accruedFeeShares();

        return _staticWithdrawOrder(super.maxWithdraw(owner));
    }

    function maxRedeem(address owner) public view override returns (uint256) {
        return _convertToShares(maxWithdraw(owner), Math.Rounding.Down);
    }

    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        _accrueFee();

        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public virtual override returns (uint256) {
        _accrueFee();

        return super.mint(shares, receiver);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        returns (uint256 shares)
    {
        _accrueFee();

        // Do not call expensive `maxWithdraw` and optimistically withdraw assets.

        shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256 assets) {
        _accrueFee();

        // Do not call expensive `maxRedeem` and optimistically redeem shares.

        assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);
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
        super._deposit(caller, owner, assets, shares);

        require(_depositOrder(assets) == 0, ErrorsLib.DEPOSIT_ORDER_FAILED);
    }

    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Blue markets.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        require(_withdrawOrder(assets) == 0, ErrorsLib.WITHDRAW_ORDER_FAILED);

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /* INTERNAL */

    function _market(Id id) internal view returns (VaultMarket storage) {
        require(_config.contains(id), ErrorsLib.UNAUTHORIZED_MARKET);

        return _config.getMarket(id);
    }

    function _supplyBalance(MarketParams memory marketParams) internal view returns (uint256) {
        return _MORPHO.expectedSupplyBalance(marketParams, address(this));
    }

    function _supplyMorpho(MarketAllocation memory allocation) internal {
        Id id = allocation.marketParams.id();

        uint256 cap = marketCap(id);
        if (cap > 0) {
            uint256 newSupply = allocation.assets + _supplyBalance(allocation.marketParams);

            require(newSupply <= cap, ErrorsLib.SUPPLY_CAP_EXCEEDED);
        }

        _MORPHO.supply(allocation.marketParams, allocation.assets, 0, address(this), hex"");
    }

    function _reallocate(MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) internal {
        uint256 nbWithdrawn = withdrawn.length;

        for (uint256 i; i < nbWithdrawn; ++i) {
            MarketAllocation memory allocation = withdrawn[i];

            _MORPHO.withdraw(allocation.marketParams, allocation.assets, 0, address(this), address(this));
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

            MarketParams memory marketParams = _config.at(_config.getMarket(id).rank);
            uint256 cap = marketCap(id);
            uint256 toDeposit = assets;

            if (cap > 0) {
                uint256 currentSupply = _supplyBalance(marketParams);

                toDeposit = UtilsLib.min(cap.zeroFloorSub(currentSupply), assets);
            }

            if (toDeposit > 0) {
                bytes memory encodedCall =
                    abi.encodeCall(_MORPHO.supply, (marketParams, toDeposit, 0, address(this), hex""));
                (bool success,) = address(_MORPHO).call(encodedCall);

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
                    abi.encodeCall(_MORPHO.withdraw, (marketParams, toWithdraw, 0, address(this), address(this)));
                (bool success,) = address(_MORPHO).staticcall(encodedCall);

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
                    abi.encodeCall(_MORPHO.withdraw, (marketParams, toWithdraw, 0, address(this), address(this)));
                (bool success,) = address(_MORPHO).call(encodedCall);

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
        marketParams = _config.at(_config.getMarket(id).rank);
        (uint256 totalSupply,, uint256 totalBorrow,) = _MORPHO.expectedMarketBalances(marketParams);
        uint256 available = totalBorrow - totalSupply;
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

    function _accrueFee() internal {
        if (fee == 0 || feeRecipient == address(0)) return;

        (uint256 newTotalAssets, uint256 feeShares) = _accruedFeeShares();

        lastTotalAssets = newTotalAssets;

        if (feeShares != 0) _mint(feeRecipient, feeShares);

        emit EventsLib.AccrueFee(newTotalAssets, feeShares);
    }

    function _accruedFeeShares() internal view returns (uint256 newTotalAssets, uint256 feeShares) {
        newTotalAssets = totalAssets();
        uint256 totalInterest = newTotalAssets.zeroFloorSub(lastTotalAssets);

        if (totalInterest != 0) {
            uint256 feeAmount = totalInterest.mulDiv(fee, WAD);
            // The fee amount is subtracted from the total assets in this calculation to compensate for the fact
            // that total assets is already increased by the total interest (including the fee amount).
            feeShares = feeAmount.mulDiv(
                totalSupply() + 10 ** _decimalsOffset(), newTotalAssets - feeAmount + 1, Math.Rounding.Down
            );
        }
    }
}
