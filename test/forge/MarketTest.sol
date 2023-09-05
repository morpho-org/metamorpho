// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract MarketTest is BaseTest {
    using MarketParamsLib for MarketParams;

    function testSetConfig(uint256 seed, VaultMarketConfig calldata marketConfigFuzz) public {
        MarketParams memory marketParamsFuzz = allMarkets[seed % allMarkets.length];

        vm.prank(RISK_MANAGER);
        vault.setConfig(marketParamsFuzz, marketConfigFuzz);

        Id id = marketParamsFuzz.id();

        VaultMarketConfig memory config = vault.config(id);

        assertEq(config.cap, marketConfigFuzz.cap);
        assertEq(Id.unwrap(vault.orderedSupply(0)), Id.unwrap(id));
        assertEq(Id.unwrap(vault.orderedWithdraw(0)), Id.unwrap(id));
    }

    function testSetConfigShouldRevertWhenInconsistenAsset(MarketParams memory marketParamsFuzz) public {
        vm.assume(marketParamsFuzz.borrowableToken != address(borrowableToken));

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.INCONSISTENT_ASSET));
        vault.setConfig(marketParamsFuzz, VaultMarketConfig({cap: 0}));
    }

    function testSetConfigShouldRevertWhenMarketNotCreated(MarketParams memory marketParamsFuzz) public {
        marketParamsFuzz.borrowableToken = address(borrowableToken);
        (,,,, uint128 lastUpdate,) = morpho.market(marketParamsFuzz.id());
        vm.assume(lastUpdate == 0);

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_CREATED));
        vault.setConfig(marketParamsFuzz, VaultMarketConfig({cap: 0}));
    }

    function testDisableMarket() public {
        MarketParams memory marketParams = allMarkets[0];

        vm.startPrank(RISK_MANAGER);
        vault.setConfig(marketParams, VaultMarketConfig({cap: 100}));

        Id id = marketParams.id();

        vault.disableMarket(id);
        vm.stopPrank();

        vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED_MARKET));
        vault.config(id);
    }

    function testDisableMarketShouldRevertWhenMarketIsNotEnabled(MarketParams memory marketParamsFuzz) public {
        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.DISABLE_MARKET_FAILED));
        vault.disableMarket(marketParamsFuzz.id());
    }
}
