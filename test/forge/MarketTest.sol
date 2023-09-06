// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract MarketTest is BaseTest {
    using MarketParamsLib for MarketParams;

    function testSubmitPendingMarket(uint256 seed, uint128 cap) public {
        MarketParams memory marketParamsFuzz = allMarkets[seed % allMarkets.length];

        vm.prank(RISK_MANAGER);
        vault.submitPendingMarket(marketParamsFuzz, cap);

        (uint128 value, uint128 timestamp) = vault.pendingMarket(marketParamsFuzz.id());
        assertEq(value, cap);
        assertEq(timestamp, block.timestamp);
    }

    function testEnableMarket(uint256 seed, uint128 cap) public {
        MarketParams memory marketParamsFuzz = allMarkets[seed % allMarkets.length];

        _submitAndEnableMarket(marketParamsFuzz, cap);

        Id id = marketParamsFuzz.id();

        assertEq(vault.marketCap(id), cap);
        assertEq(Id.unwrap(vault.supplyAllocationOrder(0)), Id.unwrap(id));
        assertEq(Id.unwrap(vault.withdrawAllocationOrder(0)), Id.unwrap(id));
    }

    function testEnableMarketShouldRevertWhenTimelockNotElapsed(uint128 timelock, uint256 timeElapsed) public {
        timelock = uint128(bound(timelock, 1, vault.MAX_TIMELOCK()));
        _submitAndSetTimelock(timelock);

        timeElapsed = bound(timeElapsed, 0, timelock - 1);

        vm.startPrank(RISK_MANAGER);
        vault.submitPendingMarket(allMarkets[0], CAP);

        vm.warp(block.timestamp + timeElapsed);

        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_ELAPSED));
        vault.enableMarket(allMarkets[0].id());
    }

    function testEnableMarketShouldRevertWhenTimelockExpirationExceeded(uint128 timelock, uint256 timeElapsed) public {
        timelock = uint128(bound(timelock, 1, vault.MAX_TIMELOCK()));
        _submitAndSetTimelock(timelock);

        timeElapsed = bound(timeElapsed, timelock + vault.TIMELOCK_EXPIRATION() + 1, type(uint128).max);

        vm.startPrank(RISK_MANAGER);
        vault.submitPendingMarket(allMarkets[0], CAP);

        vm.warp(block.timestamp + timeElapsed);

        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED));
        vault.enableMarket(allMarkets[0].id());
    }

    function testSubmitPendingMarketShouldRevertWhenInconsistenAsset(MarketParams memory marketParamsFuzz) public {
        vm.assume(marketParamsFuzz.borrowableToken != address(borrowableToken));

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.INCONSISTENT_ASSET));
        vault.submitPendingMarket(marketParamsFuzz, 0);
    }

    function testSubmitPendingMarketShouldRevertWhenMarketNotCreated(MarketParams memory marketParamsFuzz) public {
        marketParamsFuzz.borrowableToken = address(borrowableToken);
        (,,,, uint128 lastUpdate,) = morpho.market(marketParamsFuzz.id());
        vm.assume(lastUpdate == 0);

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_CREATED));
        vault.submitPendingMarket(marketParamsFuzz, 0);
    }

    function testDisableMarket() public {
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

        Id id = allMarkets[1].id();

        vm.prank(RISK_MANAGER);
        vault.disableMarket(id);

        vm.expectRevert(bytes(ErrorsLib.UNAUTHORIZED_MARKET));
        vault.marketCap(id);

        assertEq(Id.unwrap(vault.supplyAllocationOrder(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.supplyAllocationOrder(1)), Id.unwrap(allMarkets[2].id()));
    }

    function testDisableMarketShouldRevertWhenMarketIsNotEnabled(MarketParams memory marketParamsFuzz) public {
        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.DISABLE_MARKET_FAILED));
        vault.disableMarket(marketParamsFuzz.id());
    }

    function testSetSupplyAllocationOrder() public {
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

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
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

        Id[] memory supplyAllocationOrder = new Id[](3);
        supplyAllocationOrder[0] = allMarkets[0].id();
        supplyAllocationOrder[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_WHITELISTED));
        vault.setSupplyAllocationOrder(supplyAllocationOrder);
    }

    function testSetSupplyAllocationOrderRevertWhenInvalidLength() public {
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

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
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

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
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

        Id[] memory withdrawAllocationOrder = new Id[](3);
        withdrawAllocationOrder[0] = allMarkets[0].id();
        withdrawAllocationOrder[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_WHITELISTED));
        vault.setWithdrawAllocationOrder(withdrawAllocationOrder);
    }

    function testSetWithdrawAllocationOrderRevertWhenInvalidLength() public {
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

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
