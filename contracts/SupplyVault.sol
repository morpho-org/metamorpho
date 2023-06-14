// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {IPool} from "contracts/interfaces/IPool.sol";
import {IFactory} from "contracts/interfaces/IFactory.sol";
import {ISupplyVault} from "contracts/interfaces/ISupplyVault.sol";

import {FactoryLib} from "contracts/libraries/FactoryLib.sol";
import {BytesLib, POOL_OFFSET} from "contracts/libraries/BytesLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeTransferLib, ERC20 as ERC20Solmate} from "@solmate/utils/SafeTransferLib.sol";

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20, ERC20, ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {InternalSupplyRouter} from "contracts/InternalSupplyRouter.sol";

contract SupplyVault is ISupplyVault, ERC4626, Ownable2Step, InternalSupplyRouter {
    using FactoryLib for IFactory;
    using SafeTransferLib for ERC20Solmate;
    using EnumerableSet for EnumerableSet.AddressSet;

    address private _riskManager;
    address private _allocationManager;

    Config private _config;

    constructor(address factory, string memory name_, string memory symbol_, IERC20 asset_)
        ERC4626(asset_)
        ERC20(name_, symbol_)
        InternalSupplyRouter(factory)
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

    function setCollateralEnabled(address collateral, bool enabled) external virtual onlyRiskManager {
        _setCollateralEnabled(collateral, enabled);
    }

    function setCollateralConfig(address collateral, CollateralConfig calldata collateralConfig)
        external
        virtual
        onlyRiskManager
    {
        _setCollateralConfig(collateral, collateralConfig);
    }

    function reallocate(bytes calldata withdrawn, bytes calldata supplied) external virtual onlyAllocationManager {
        _reallocate(withdrawn, supplied);
    }

    /* PUBLIC */

    function riskManager() public view virtual returns (address) {
        return _riskManager;
    }

    function allocationManager() public view virtual returns (address) {
        return _allocationManager;
    }

    function config(address collateral) public view virtual returns (CollateralConfig memory) {
        return _collateralConfig(collateral);
    }

    /**
     * @dev See {IERC4626-totalAssets}.
     */
    function totalAssets() public view virtual override returns (uint256 assets) {
        EnumerableSet.AddressSet storage collaterals = _config.collaterals;

        uint256 nbCollaterals = collaterals.length();
        for (uint256 i; i < nbCollaterals; ++i) {
            address collateral = collaterals.at(i);
            CollateralConfig storage collateralConfig = _collateralConfig(collateral);

            assets += _FACTORY.getPool(asset(), collateral).supplyBalanceOf(address(this), collateralConfig.bucket);
        }
    }

    /* INTERNAL */

    function _checkRiskManager() internal view virtual {
        if (riskManager() != _msgSender()) revert OnlyRiskManager();
    }

    function _checkAllocationManager() internal view virtual {
        if (allocationManager() != _msgSender()) revert OnlyAllocationManager();
    }

    function _collateralConfig(address collateral) internal view virtual returns (CollateralConfig storage) {
        return _config.collateralConfig[collateral];
    }

    function _setCollateralEnabled(address collateral, bool enabled) internal virtual {
        if (enabled) _config.collaterals.add(collateral);
        else _config.collaterals.remove(collateral);
    }

    function _setCollateralConfig(address collateral, CollateralConfig calldata collateralConfig) internal virtual {
        _config.collateralConfig[collateral] = collateralConfig;
    }

    function _reallocate(bytes calldata withdrawn, bytes calldata supplied) internal virtual {
        address _asset = asset();

        _withdraw(_asset, withdrawn, address(this));
        _supply(_asset, supplied, address(this));
    }
}
