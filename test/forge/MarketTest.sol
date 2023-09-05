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
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));

        Id id = allMarkets[1].id();

        vault.disableMarket(id);
        vm.stopPrank();

        vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED_MARKET));
        vault.config(id);

        assertEq(Id.unwrap(vault.orderedSupply(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.orderedSupply(1)), Id.unwrap(allMarkets[2].id()));
    }

    function testDisableMarketShouldRevertWhenMarketIsNotEnabled(MarketParams memory marketParamsFuzz) public {
        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.DISABLE_MARKET_FAILED));
        vault.disableMarket(marketParamsFuzz.id());
    }

    function testSetOrderedSupply() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));

        assertEq(Id.unwrap(vault.orderedSupply(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.orderedSupply(1)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.orderedSupply(2)), Id.unwrap(allMarkets[2].id()));

        Id[] memory orderedSupply = new Id[](3);
        orderedSupply[0] = allMarkets[1].id();
        orderedSupply[1] = allMarkets[2].id();
        orderedSupply[2] = allMarkets[0].id();

        vault.setOrderedSupply(orderedSupply);

        assertEq(Id.unwrap(vault.orderedSupply(0)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.orderedSupply(1)), Id.unwrap(allMarkets[2].id()));
        assertEq(Id.unwrap(vault.orderedSupply(2)), Id.unwrap(allMarkets[0].id()));
    }

    function testSetOrderedSupplyRevertWhenMissingAtLeastOneMarket() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));

        Id[] memory orderedSupply = new Id[](3);
        orderedSupply[0] = allMarkets[0].id();
        orderedSupply[1] = allMarkets[1].id();

        vm.expectRevert(bytes(ErrorsLib.INVALID_ORDERED_MARKETS));
        vault.setOrderedSupply(orderedSupply);
    }

    function testSetOrderedSupplyRevertWhenInvalidLength() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));

        Id[] memory orderedSupply1 = new Id[](2);
        orderedSupply1[0] = allMarkets[0].id();
        orderedSupply1[1] = allMarkets[1].id();

        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setOrderedSupply(orderedSupply1);

        Id[] memory orderedSupply2 = new Id[](4);
        orderedSupply2[0] = allMarkets[0].id();
        orderedSupply2[1] = allMarkets[1].id();
        orderedSupply2[2] = allMarkets[2].id();
        orderedSupply2[3] = allMarkets[3].id();

        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setOrderedSupply(orderedSupply2);
    }

    function testSetOrderedWithdraw() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));

        assertEq(Id.unwrap(vault.orderedWithdraw(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.orderedWithdraw(1)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.orderedWithdraw(2)), Id.unwrap(allMarkets[2].id()));

        Id[] memory orderedWithdraw = new Id[](3);
        orderedWithdraw[0] = allMarkets[1].id();
        orderedWithdraw[1] = allMarkets[2].id();
        orderedWithdraw[2] = allMarkets[0].id();

        vault.setOrderedWithdraw(orderedWithdraw);

        assertEq(Id.unwrap(vault.orderedWithdraw(0)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.orderedWithdraw(1)), Id.unwrap(allMarkets[2].id()));
        assertEq(Id.unwrap(vault.orderedWithdraw(2)), Id.unwrap(allMarkets[0].id()));
    }

    function testSetOrderedWithdrawRevertWhenMissingAtLeastOneMarket() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));

        Id[] memory orderedWithdraw = new Id[](3);
        orderedWithdraw[0] = allMarkets[0].id();
        orderedWithdraw[1] = allMarkets[1].id();

        vm.expectRevert(bytes(ErrorsLib.INVALID_ORDERED_MARKETS));
        vault.setOrderedWithdraw(orderedWithdraw);
    }

    function testSetOrderedWithdrawRevertWhenInvalidLength() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));

        Id[] memory orderedWithdraw1 = new Id[](2);
        orderedWithdraw1[0] = allMarkets[0].id();
        orderedWithdraw1[1] = allMarkets[1].id();

        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setOrderedWithdraw(orderedWithdraw1);

        Id[] memory orderedWithdraw2 = new Id[](4);
        orderedWithdraw2[0] = allMarkets[0].id();
        orderedWithdraw2[1] = allMarkets[1].id();
        orderedWithdraw2[2] = allMarkets[2].id();
        orderedWithdraw2[3] = allMarkets[3].id();

        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setOrderedWithdraw(orderedWithdraw2);
    }
}
