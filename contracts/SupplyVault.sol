// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {ISupplyVault} from "contracts/interfaces/ISupplyVault.sol";

import {MarketAllocation, MarketConfig, Market, ConfigSet} from "./libraries/Types.sol";
import {SupplyOverCap} from "./libraries/Errors.sol";
import {ConfigSetLib} from "./libraries/ConfigSetLib.sol";
import {MarketLib} from "./libraries/MarketLib.sol";
import {TrancheMemLib} from "@morpho-blue/libraries/TrancheLib.sol";
import {MarketKey, TrancheId, Tranche, TrancheShares} from "@morpho-blue/libraries/Types.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20, ERC20, ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {InternalSupplyRouter} from "contracts/InternalSupplyRouter.sol";

contract SupplyVault is ISupplyVault, ERC4626, Ownable2Step, InternalSupplyRouter {
    using ConfigSetLib for ConfigSet;
    using TrancheMemLib for Tranche;

    using MarketLib for Market;

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

    function disableMarket(MarketKey calldata marketKey) external virtual onlyRiskManager {
        _config.remove(marketKey);
    }

    function setMarketConfig(MarketKey calldata marketKey, MarketConfig calldata marketConfig)
        external
        virtual
        onlyRiskManager
    {
        _config.add(marketKey, marketConfig);
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
            Market storage market = _market(marketKey);

            uint256 nbTranches = market.nbTranches();
            for (uint256 j; j < nbTranches; ++j) {
                TrancheId trancheId = market.trancheAt(j);

                Tranche memory tranche = _MORPHO.trancheAt(marketKey, trancheId);
                (, TrancheShares memory shares) = _MORPHO.sharesOf(marketKey, trancheId, address(this));

                assets += tranche.toSupplyAssets(shares);
            }
        }
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

    function _supply(MarketAllocation calldata allocation, address onBehalf) internal override {
        Market storage market = _market(allocation.marketKey);

        uint256 cap = market.config.cap;
        if (cap > 0) {
            uint256 supply = allocation.assets;

            uint256 nbTranches = market.nbTranches();
            for (uint256 i; i < nbTranches; ++i) {
                TrancheId trancheId = market.trancheAt(i);

                Tranche memory tranche = _MORPHO.trancheAt(allocation.marketKey, trancheId);
                (, TrancheShares memory shares) = _MORPHO.sharesOf(allocation.marketKey, trancheId, address(this));

                supply += tranche.toSupplyAssets(shares);
            }

            if (cap < supply) revert SupplyOverCap(supply);
        }

        super._supply(allocation, onBehalf);
    }

    function _withdraw(MarketAllocation calldata allocation, address onBehalf, address receiver) internal override {
        super._withdraw(allocation, onBehalf, receiver);
    }

    function _reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied)
        internal
        virtual
    {
        // if (_config.collaterals.) revert UnauthorizedMarket(_asset);

        _withdrawAll(withdrawn, address(this), address(this));
        _supplyAll(supplied, address(this));
    }
}
