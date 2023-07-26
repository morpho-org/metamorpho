// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {Market} from "@morpho-blue/interfaces/IBlue.sol";
import {ISupplyVault} from "contracts/interfaces/ISupplyVault.sol";
import {IVaultAllocationManager} from "contracts/interfaces/IVaultAllocationManager.sol";

import {Events} from "contracts/libraries/Events.sol";
import {MarketAllocation, Signature} from "contracts/libraries/Types.sol";
import {UnauthorizedMarket, InconsistentAsset, SupplyCapExceeded} from "contracts/libraries/Errors.sol";
import {MarketConfig, MarketConfigData, ConfigSet, ConfigSetLib} from "contracts/libraries/ConfigSetLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {InternalSupplyRouter, ERC2771Context} from "contracts/InternalSupplyRouter.sol";
import {IERC20, ERC20, ERC4626, Context} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract SupplyVault is ISupplyVault, ERC4626, Ownable, InternalSupplyRouter {
    using ConfigSetLib for ConfigSet;

    address private _riskManager;
    address private _allocationManager;

    ConfigSet private _config;

    constructor(address morpho, address forwarder, string memory name_, string memory symbol_, IERC20 asset_)
        ERC20(name_, symbol_)
        ERC4626(asset_)
        InternalSupplyRouter(morpho, forwarder)
    {}

    modifier onlyRiskManager() {
        _checkRiskManager();
        _;
    }

    modifier onlyAllocationManager() {
        _checkAllocationManager();
        _;
    }

    /* EXTERNAL */

    function setRiskManager(address newRiskManager) external onlyOwner {
        _setRiskManager(newRiskManager);
    }

    function setAllocationManager(address newAllocationManager) external onlyOwner {
        _setAllocationManager(newAllocationManager);
    }

    function setMarketConfig(Market memory market, MarketConfigData calldata marketConfig)
        external
        virtual
        onlyRiskManager
    {
        address _asset = address(market.borrowableAsset);
        if (_asset != asset()) revert InconsistentAsset(_asset);

        _config.add(market, marketConfig);
    }

    function disableMarket(Market memory market) external virtual onlyRiskManager {
        _config.remove(market);
    }

    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied)
        external
        virtual
        onlyAllocationManager
    {
        _reallocate(withdrawn, supplied);
    }

    /* PUBLIC */

    function riskManager() public view virtual returns (address) {
        return _riskManager;
    }

    function allocationManager() public view virtual returns (address) {
        return _allocationManager;
    }

    function config(Market memory market) public view virtual returns (MarketConfigData memory) {
        return _market(market).config;
    }

    /* ERC4626 */

    function totalAssets() public view override returns (uint256 assets) {
        uint256 nbMarkets = _config.length();

        for (uint256 i; i < nbMarkets; ++i) {
            Market storage market = _config.at(i);

            // assets += _supplyBalance(allocation.market);
        }
    }

    // TODO: maxWithdraw, maxRedeem are limited by markets liquidity

    /// @dev Used in mint or deposit to deposit the underlying asset to Blue markets.
    function _deposit(address caller, address owner, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, owner, assets, shares);

        // TODO: MarketAllocation[] could be bytes and save gas

        (MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) =
            IVaultAllocationManager(_allocationManager).allocateSupply(caller, owner, assets, shares);

        _reallocate(withdrawn, supplied);
    }

    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Blue markets.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        (MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) =
            IVaultAllocationManager(_allocationManager).allocateWithdraw(caller, receiver, owner, assets, shares);

        _reallocate(withdrawn, supplied);

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /* INTERNAL */

    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _checkRiskManager() internal view {
        if (_msgSender() != riskManager()) revert OnlyRiskManager();
    }

    function _checkAllocationManager() internal view {
        if (_msgSender() != allocationManager()) revert OnlyAllocationManager();
    }

    function _market(Market memory market) internal view returns (MarketConfig storage) {
        return _config.getMarket(market);
    }

    function _setRiskManager(address newRiskManager) internal {
        _riskManager = newRiskManager;

        emit Events.RiskManagerSet(newRiskManager);
    }

    function _setAllocationManager(address newAllocationManager) internal {
        _riskManager = newAllocationManager;

        emit Events.AllocationManagerSet(newAllocationManager);
    }

    function _supplyBalance(Market memory market) internal returns (uint256) {
        // TODO: use accrued interests
    }

    function _supply(MarketAllocation memory allocation, address onBehalf) internal override {
        if (!_config.contains(allocation.market)) revert UnauthorizedMarket(allocation.market);

        MarketConfig storage market = _market(allocation.market);

        uint256 cap = market.config.cap;
        if (cap > 0) {
            uint256 newSupply = allocation.assets + _supplyBalance(allocation.market);

            if (newSupply > cap) revert SupplyCapExceeded(newSupply);
        }

        super._supply(allocation, onBehalf);
    }

    function _reallocate(MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) internal {
        _withdrawAll(withdrawn, address(this), address(this));
        _supplyAll(supplied, address(this));
    }
}
