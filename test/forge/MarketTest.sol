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
        assertEq(Id.unwrap(vault.supplyAllocationOrder(0)), Id.unwrap(id));
        assertEq(Id.unwrap(vault.withdrawAllocationOrder(0)), Id.unwrap(id));
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

        assertEq(Id.unwrap(vault.supplyAllocationOrder(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.supplyAllocationOrder(1)), Id.unwrap(allMarkets[2].id()));
    }

    function testDisableMarketShouldRevertWhenMarketIsNotEnabled(MarketParams memory marketParamsFuzz) public {
        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.DISABLE_MARKET_FAILED));
        vault.disableMarket(marketParamsFuzz.id());
    }

    function testSetSupplyAllocationOrder() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));
        vm.stopPrank();

        assertEq(Id.unwrap(vault.supplyAllocationOrder(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.supplyAllocationOrder(1)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.supplyAllocationOrder(2)), Id.unwrap(allMarkets[2].id()));

        Id[] memory supplyAllocationOrder = new Id[](3);
        supplyAllocationOrder[0] = allMarkets[1].id();
        supplyAllocationOrder[1] = allMarkets[2].id();
        supplyAllocationOrder[2] = allMarkets[0].id();

        vm.prank(ALLOCATOR);
        vault.setSupplyAllocationOrder(supplyAllocationOrder);

        assertEq(Id.unwrap(vault.supplyAllocationOrder(0)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.supplyAllocationOrder(1)), Id.unwrap(allMarkets[2].id()));
        assertEq(Id.unwrap(vault.supplyAllocationOrder(2)), Id.unwrap(allMarkets[0].id()));
    }

    function testSetSupplyAllocationOrderRevertWhenMissingAtLeastOneMarket() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));
        vm.stopPrank();

        Id[] memory supplyAllocationOrder = new Id[](3);
        supplyAllocationOrder[0] = allMarkets[0].id();
        supplyAllocationOrder[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_WHITELISTED));
        vault.setSupplyAllocationOrder(supplyAllocationOrder);
    }

    function testSetSupplyAllocationOrderRevertWhenInvalidLength() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));
        vm.stopPrank();

        Id[] memory supplyAllocationOrder1 = new Id[](2);
        supplyAllocationOrder1[0] = allMarkets[0].id();
        supplyAllocationOrder1[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setSupplyAllocationOrder(supplyAllocationOrder1);

        Id[] memory supplyAllocationOrder2 = new Id[](4);
        supplyAllocationOrder2[0] = allMarkets[0].id();
        supplyAllocationOrder2[1] = allMarkets[1].id();
        supplyAllocationOrder2[2] = allMarkets[2].id();
        supplyAllocationOrder2[3] = allMarkets[3].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setSupplyAllocationOrder(supplyAllocationOrder2);
    }

    function testSetWithdrawAllocationOrder() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));
        vm.stopPrank();

        assertEq(Id.unwrap(vault.withdrawAllocationOrder(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.withdrawAllocationOrder(1)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.withdrawAllocationOrder(2)), Id.unwrap(allMarkets[2].id()));

        Id[] memory withdrawAllocationOrder = new Id[](3);
        withdrawAllocationOrder[0] = allMarkets[1].id();
        withdrawAllocationOrder[1] = allMarkets[2].id();
        withdrawAllocationOrder[2] = allMarkets[0].id();

        vm.prank(ALLOCATOR);
        vault.setWithdrawAllocationOrder(withdrawAllocationOrder);

        assertEq(Id.unwrap(vault.withdrawAllocationOrder(0)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.withdrawAllocationOrder(1)), Id.unwrap(allMarkets[2].id()));
        assertEq(Id.unwrap(vault.withdrawAllocationOrder(2)), Id.unwrap(allMarkets[0].id()));
    }

    function testSetWithdrawAllocationOrderRevertWhenMissingAtLeastOneMarket() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));
        vm.stopPrank();

        Id[] memory withdrawAllocationOrder = new Id[](3);
        withdrawAllocationOrder[0] = allMarkets[0].id();
        withdrawAllocationOrder[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_WHITELISTED));
        vault.setWithdrawAllocationOrder(withdrawAllocationOrder);
    }

    function testSetWithdrawAllocationOrderRevertWhenInvalidLength() public {
        vm.startPrank(RISK_MANAGER);
        vault.setConfig(allMarkets[0], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[1], VaultMarketConfig({cap: 100}));
        vault.setConfig(allMarkets[2], VaultMarketConfig({cap: 100}));
        vm.stopPrank();

        Id[] memory withdrawAllocationOrder1 = new Id[](2);
        withdrawAllocationOrder1[0] = allMarkets[0].id();
        withdrawAllocationOrder1[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setWithdrawAllocationOrder(withdrawAllocationOrder1);

        Id[] memory withdrawAllocationOrder2 = new Id[](4);
        withdrawAllocationOrder2[0] = allMarkets[0].id();
        withdrawAllocationOrder2[1] = allMarkets[1].id();
        withdrawAllocationOrder2[2] = allMarkets[2].id();
        withdrawAllocationOrder2[3] = allMarkets[3].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setWithdrawAllocationOrder(withdrawAllocationOrder2);
    }
}
