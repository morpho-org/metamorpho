// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ISupplyVault} from "./interfaces/ISupplyVault.sol";
import {IVaultAllocationManager} from "./interfaces/IVaultAllocationManager.sol";

import {Events} from "./libraries/Events.sol";
import {MarketAllocation} from "./libraries/Types.sol";
import {IMorpho, MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import {UnauthorizedMarket, InconsistentAsset, SupplyCapExceeded} from "./libraries/Errors.sol";
import {MarketConfig, MarketConfigData, ConfigSet, ConfigSetLib} from "./libraries/ConfigSetLib.sol";
import {Id, MarketParams, MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {InternalSupplyRouter, ERC2771Context} from "./InternalSupplyRouter.sol";
import {IERC20, ERC20, ERC4626, Context} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract SupplyVault is ISupplyVault, InternalSupplyRouter, ERC4626, Ownable {
    using MorphoLib for IMorpho;
    using SharesMathLib for uint256;
    using ConfigSetLib for ConfigSet;
    using MarketParamsLib for MarketParams;

    address private _riskManager;
    address private _allocationManager;

    ConfigSet private _config;

    constructor(address morpho, address forwarder, string memory name_, string memory symbol_, IERC20 asset_)
        InternalSupplyRouter(morpho, forwarder)
        ERC20(name_, symbol_)
        ERC4626(asset_)
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

    function setMarketConfig(MarketParams memory marketParams, MarketConfigData calldata marketConfig)
        external
        virtual
        onlyRiskManager
    {
        address _asset = address(marketParams.borrowableToken);
        if (_asset != asset()) revert InconsistentAsset(_asset);

        _config.update(marketParams.id(), marketConfig);
    }

    function disableMarket(Id id) external virtual onlyRiskManager {
        _config.remove(id);
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

    function config(Id id) public view virtual returns (MarketConfigData memory) {
        return _market(id).config;
    }

    /* ERC4626 */

    function totalAssets() public view override returns (uint256 assets) {
        uint256 nbMarkets = _config.length();

        for (uint256 i; i < nbMarkets; ++i) {
            Id id = _config.at(i);

            assets += _supplyBalance(id);
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

    function _market(Id id) internal view returns (MarketConfig storage) {
        return _config.getMarket(id);
    }

    function _setRiskManager(address newRiskManager) internal {
        _riskManager = newRiskManager;

        emit Events.RiskManagerSet(newRiskManager);
    }

    function _setAllocationManager(address newAllocationManager) internal {
        _riskManager = newAllocationManager;

        emit Events.AllocationManagerSet(newAllocationManager);
    }

    function _supplyBalance(Id marketId) internal view returns (uint256) {
        // TODO: calculate accrued interests
        return _MORPHO.supplyShares(marketId, address(this)).toAssetsDown(
            _MORPHO.totalSupplyAssets(marketId), _MORPHO.totalSupplyShares(marketId)
        );
    }

    function _supply(MarketAllocation memory allocation, address onBehalf) internal override {
        Id id = allocation.marketParams.id();
        if (!_config.contains(id)) revert UnauthorizedMarket(allocation.marketParams);

        MarketConfig storage marketParams = _market(id);

        uint256 cap = marketParams.config.cap;
        if (cap > 0) {
            uint256 newSupply = allocation.assets + _supplyBalance(id);

            if (newSupply > cap) revert SupplyCapExceeded(newSupply);
        }

        super._supply(allocation, onBehalf);
    }

    function _reallocate(MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) internal {
        _withdrawAll(withdrawn, address(this), address(this));
        _supplyAll(supplied, address(this));
    }
}
