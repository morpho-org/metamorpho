// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {ISupplyVault} from "contracts/interfaces/ISupplyVault.sol";
import {IVaultAllocationManager} from "contracts/interfaces/IVaultAllocationManager.sol";

import {MarketAllocation, MarketConfig, Market, ConfigSet} from "./libraries/Types.sol";
import {UnauthorizedMarket, InconsistentAsset, SupplyOverCap} from "./libraries/Errors.sol";
import {ConfigSetLib} from "./libraries/ConfigSetLib.sol";
import {MarketKey, MarketState, MarketShares, Position} from "@morpho-blue/libraries/Types.sol";
import {MarketStateMemLib} from "@morpho-blue/libraries/MarketStateLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20, ERC20, ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {InternalSupplyRouter} from "contracts/InternalSupplyRouter.sol";

contract SupplyVault is ISupplyVault, ERC4626, Ownable2Step, InternalSupplyRouter {
    using ConfigSetLib for ConfigSet;

    using MarketStateMemLib for MarketState;

    address private _riskManager;
    address private _allocationManager;

    ConfigSet private _config;

    constructor(address morpho, string memory name_, string memory symbol_, IERC20 asset_)
        ERC4626(asset_)
        ERC20(name_, symbol_)
        InternalSupplyRouter(morpho)
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

    function setMarketConfig(MarketKey calldata marketKey, MarketConfig calldata marketConfig)
        external
        virtual
        onlyRiskManager
    {
        address _asset = address(marketKey.asset);
        if (_asset != asset()) revert InconsistentAsset(_asset);

        _config.add(marketKey, marketConfig);
    }

    function disableMarket(MarketKey calldata marketKey) external virtual onlyRiskManager {
        _config.remove(marketKey);
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

    function config(MarketKey calldata marketKey) public view virtual returns (MarketConfig memory) {
        return _market(marketKey).config;
    }

    /**
     * @dev See {IERC4626-totalAssets}.
     */
    function totalAssets() public view virtual override returns (uint256 assets) {
        uint256 nbMarkets = _config.length();

        for (uint256 i; i < nbMarkets; ++i) {
            MarketKey storage marketKey = _config.at(i);

            MarketState memory state = _MORPHO.stateAt(marketKey);
            Position memory position = _MORPHO.positionOf(marketKey, address(this));

            assets += state.toSupplyAssets(position.shares);
        }
    }

    /* ERC4626 */

    // TODO: maxWithdraw, maxRedeem are limited by markets liquidity

    /// @dev Used in mint or deposit to deposit the underlying asset to Blue markets.
    function _deposit(address caller, address owner, uint256 assets, uint256 shares) internal virtual override {
        super._deposit(caller, owner, assets, shares);

        // TODO: MarketAllocation[] could be bytes and save gas

        (MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) =
            IVaultAllocationManager(_allocationManager).allocateSupply(caller, owner, assets, shares);

        _reallocate(withdrawn, supplied);
    }

    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Blue markets.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        (MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) =
            IVaultAllocationManager(_allocationManager).allocateWithdraw(caller, receiver, owner, assets, shares);

        _reallocate(withdrawn, supplied);

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /* INTERNAL */

    function _checkRiskManager() internal view virtual {
        if (riskManager() != _msgSender()) revert OnlyRiskManager();
    }

    function _checkAllocationManager() internal view virtual {
        if (allocationManager() != _msgSender()) revert OnlyAllocationManager();
    }

    function _market(MarketKey memory marketKey) internal view virtual returns (Market storage) {
        return _config.getMarket(marketKey);
    }

    function _deposit(MarketAllocation memory allocation, address onBehalf) internal override {
        if (!_config.contains(allocation.marketKey)) revert UnauthorizedMarket(allocation.marketKey);

        Market storage market = _market(allocation.marketKey);

        uint256 cap = market.config.cap;
        if (cap > 0) {
            MarketState memory state = _MORPHO.stateAt(allocation.marketKey);
            Position memory position = _MORPHO.positionOf(allocation.marketKey, address(this));

            uint256 supply = allocation.assets + state.toSupplyAssets(position.shares);

            if (supply > cap) revert SupplyOverCap(supply);
        }

        super._deposit(allocation, onBehalf);
    }

    function _reallocate(MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) internal virtual {
        _withdrawAll(withdrawn, address(this), address(this));
        _depositAll(supplied, address(this));
    }
}
