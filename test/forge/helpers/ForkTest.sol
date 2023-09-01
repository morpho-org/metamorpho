// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Permit2Lib} from "@permit2/libraries/Permit2Lib.sol";
import {PermitHash} from "@permit2/libraries/PermitHash.sol";

import "config/Configured.sol";
import "./BaseTest.sol";

abstract contract ForkTest is BaseTest, Configured {
    using ConfigLib for Config;
    using SafeTransferLib for ERC20;

    string internal network;
    uint256 internal forkId;

    uint256 internal snapshotId = type(uint256).max;

    MarketParams[] allMarketParams;

    constructor() {
        _initConfig();
        _loadConfig();

        _setBalances(address(this), type(uint96).max);
    }

    function setUp() public virtual override {
        _label();

        super.setUp();

        for (uint256 i; i < configMarkets.length; ++i) {
            ConfigMarket memory configMarket = configMarkets[i];

            MarketParams memory marketParams = MarketParams({
                collateralToken: configMarket.collateralToken,
                borrowableToken: configMarket.borrowableToken,
                oracle: address(oracle),
                irm: address(irm),
                lltv: configMarket.lltv
            });

            vm.startPrank(OWNER);
            if (!morpho.isLltvEnabled(configMarket.lltv)) morpho.enableLltv(configMarket.lltv);
            morpho.createMarket(marketParams);
            vm.stopPrank();

            allMarketParams.push(marketParams);
        }
    }

    function _fork() internal virtual {
        string memory rpcUrl = vm.rpcUrl(_rpcAlias());
        uint256 forkBlockNumber = CONFIG.getForkBlockNumber();

        forkId = forkBlockNumber == 0 ? vm.createSelectFork(rpcUrl) : vm.createSelectFork(rpcUrl, forkBlockNumber);
        vm.chainId(CONFIG.getChainId());
    }

    function _loadConfig() internal virtual override {
        super._loadConfig();

        _fork();
    }

    function _label() internal virtual {
        for (uint256 i; i < allAssets.length; ++i) {
            address asset = allAssets[i];
            string memory symbol = ERC20(asset).symbol();

            vm.label(asset, symbol);
        }
    }

    function _setBalances(address user, uint256 balance) internal {
        for (uint256 i; i < allAssets.length; ++i) {
            address asset = allAssets[i];

            deal(asset, user, balance / (10 ** (18 - ERC20(asset).decimals())));
        }
    }

    /// @dev Avoids to revert because of AAVE token snapshots:
    /// https://github.com/aave/aave-token-v2/blob/master/contracts/token/base/GovernancePowerDelegationERC20.sol#L174
    function _deal(address asset, address user, uint256 amount) internal {
        if (amount == 0) return;

        if (asset == WETH) deal(WETH, WETH.balance + amount); // Refill wrapped Ether.

        deal(asset, user, amount);
    }

    /// @dev Reverts the fork to its initial fork state.
    function _revert() internal {
        if (snapshotId < type(uint256).max) vm.revertTo(snapshotId);
        snapshotId = vm.snapshot();
    }

    function _assumeNotAsset(address input) internal view {
        for (uint256 i; i < allAssets.length; ++i) {
            vm.assume(input != allAssets[i]);
        }
    }

    function _assumeNotLsdNative(address input) internal view {
        for (uint256 i; i < lsdNatives.length; ++i) {
            vm.assume(input != lsdNatives[i]);
        }
    }

    function _randomAsset(uint256 seed) internal view returns (address) {
        return allAssets[seed % allAssets.length];
    }

    function _randomLsdNative(uint256 seed) internal view returns (address) {
        return lsdNatives[seed % lsdNatives.length];
    }

    function _randomMarketParams(uint256 seed) internal view returns (MarketParams memory) {
        return allMarketParams[seed % allMarketParams.length];
    }
}
