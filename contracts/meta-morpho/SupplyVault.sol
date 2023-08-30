// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {MarketAllocation, ISupplyVault} from "./interfaces/ISupplyVault.sol";
import {IVaultAllocationStrategy} from "./interfaces/IVaultAllocationStrategy.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";
import {MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import {VaultMarket, VaultMarketConfig, ConfigSet, ConfigSetLib} from "./libraries/ConfigSetLib.sol";
import {Id, MarketParams, MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {InternalSupplyRouter, ERC2771Context} from "./InternalSupplyRouter.sol";
import {IERC20, ERC20, ERC4626, Context} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract SupplyVault is InternalSupplyRouter, ERC4626, Ownable2Step, ISupplyVault {
    using MorphoLib for IMorpho;
    using SharesMathLib for uint256;
    using ConfigSetLib for ConfigSet;
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;

    mapping(address => bool) public isRiskManager;
    mapping(address => bool) public isAllocator;

    IVaultAllocationStrategy public supplyStrategy;
    IVaultAllocationStrategy public withdrawStrategy;

    ConfigSet private _config;

    /* CONSTRUCTORS */

    constructor(address morpho, address forwarder, IERC20 asset_, string memory name_, string memory symbol_)
        InternalSupplyRouter(morpho, forwarder)
        ERC4626(asset_)
        ERC20(name_, symbol_)
    {}

    /* MODIFIERS */

    modifier onlyRiskManager() {
        require(isRiskManager[_msgSender()], ErrorsLib.NOT_RISK_MANAGER);

        _;
    }

    modifier onlyAllocator() {
        require(isAllocator[_msgSender()], ErrorsLib.NOT_ALLOCATOR);

        _;
    }

    /* ONLY OWNER FUNCTIONS */

    function setIsRiskManager(address newRiskManager, bool newIsRiskManager) external onlyOwner {
        isRiskManager[newRiskManager] = newIsRiskManager;

        emit EventsLib.SetRiskManager(newRiskManager, newIsRiskManager);
    }

    function setAllocator(address newAllocator, bool newIsAllocator) external onlyOwner {
        isAllocator[newAllocator] = newIsAllocator;

        emit EventsLib.SetAllocator(newAllocator, newIsAllocator);
    }

    function setSupplyStrategy(address newSupplyStrategy) external onlyOwner {
        supplyStrategy = IVaultAllocationStrategy(newSupplyStrategy);

        emit EventsLib.SetSupplyStrategy(newSupplyStrategy);
    }

    function setWithdrawStrategy(address newWithdrawStrategy) external onlyOwner {
        withdrawStrategy = IVaultAllocationStrategy(newWithdrawStrategy);

        emit EventsLib.SetWithdrawStrategy(newWithdrawStrategy);
    }

    /* EXTERNAL */

    function setConfig(MarketParams memory marketParams, VaultMarketConfig calldata marketConfig)
        external
        onlyRiskManager
    {
        require(marketParams.borrowableToken == asset(), ErrorsLib.INCONSISTENT_ASSET);

        _config.update(marketParams, marketConfig);
    }

    function disableMarket(Id id) external onlyRiskManager {
        _config.remove(id);
    }

    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied)
        external
        onlyAllocator
    {
        _reallocate(withdrawn, supplied);
    }

    /* PUBLIC */

    function config(Id id) public view returns (VaultMarketConfig memory) {
        return _market(id).config;
    }

    /* ERC4626 */

    function totalAssets() public view override returns (uint256 assets) {
        uint256 nbMarkets = _config.length();

        for (uint256 i; i < nbMarkets; ++i) {
            MarketParams memory marketParams = _config.at(i);

            assets += _supplyBalance(marketParams);
        }
    }

    // TODO: maxWithdraw, maxRedeem are limited by markets liquidity

    /// @dev Used in mint or deposit to deposit the underlying asset to Blue markets.
    function _deposit(address caller, address owner, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, owner, assets, shares);

        // TODO: MarketAllocation[] could be bytes and save gas

        if (address(supplyStrategy) != address(0)) {
            (MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) =
                supplyStrategy.allocate(caller, owner, assets, shares);

            _reallocate(withdrawn, supplied);
        }
    }

    /// @dev Used in redeem or withdraw to withdraw the underlying asset from Blue markets.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        if (address(withdrawStrategy) != address(0)) {
            (MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) =
                withdrawStrategy.allocate(caller, owner, assets, shares);

            _reallocate(withdrawn, supplied);
        }

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /* INTERNAL */

    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    function _market(Id id) internal view returns (VaultMarket storage) {
        return _config.getMarket(id);
    }

    function _supplyBalance(MarketParams memory marketParams) internal view returns (uint256) {
        return _MORPHO.expectedSupplyBalance(marketParams, address(this));
    }

    function _supply(MarketAllocation memory allocation, address onBehalf) internal override {
        Id id = allocation.marketParams.id();
        require(_config.contains(id), ErrorsLib.UNAUTHORIZED_MARKET);

        VaultMarket storage market = _market(id);

        uint256 cap = market.config.cap;
        if (cap > 0) {
            uint256 newSupply = allocation.assets + _supplyBalance(allocation.marketParams);

            require(newSupply <= cap, ErrorsLib.SUPPLY_CAP_EXCEEDED);
        }

        super._supply(allocation, onBehalf);
    }

    function _reallocate(MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied) internal {
        _withdrawAll(withdrawn, address(this), address(this));
        _supplyAll(supplied, address(this));
    }
}
