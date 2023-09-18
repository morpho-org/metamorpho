// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

contract MarketTest is BaseTest {
    using MarketParamsLib for MarketParams;

    function testSubmitPendingMarket(uint256 seed, uint128 cap) public {
        MarketParams memory marketParamsFuzz = allMarkets[seed % allMarkets.length];

        vm.prank(RISK_MANAGER);
        vault.submitMarket(marketParamsFuzz, cap);

        (uint128 value, uint128 timestamp) = vault.pendingMarket(marketParamsFuzz.id());
        assertEq(value, cap);
        assertEq(timestamp, block.timestamp);
    }

    function testEnableMarket(uint256 seed, uint128 cap) public {
        MarketParams memory marketParamsFuzz = allMarkets[seed % allMarkets.length];

        _submitAndEnableMarket(marketParamsFuzz, cap);

        Id id = marketParamsFuzz.id();

        assertEq(vault.marketCap(id), cap);
        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(id));
        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(id));
    }

    function testEnableMarketShouldRevertWhenAlreadyEnabled() public {
        _submitAndEnableMarket(allMarkets[0], CAP);

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.ENABLE_MARKET_FAILED));
        vault.enableMarket(allMarkets[0].id());
    }

    function testEnableMarketShouldRevertWhenTimelockNotElapsed(uint128 timelock, uint256 timeElapsed) public {
        timelock = uint128(bound(timelock, 1, MAX_TIMELOCK));
        _submitAndSetTimelock(timelock);

        timeElapsed = bound(timeElapsed, 0, timelock - 1);

        vm.startPrank(RISK_MANAGER);
        vault.submitMarket(allMarkets[0], CAP);

        vm.warp(block.timestamp + timeElapsed);

        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_ELAPSED));
        vault.enableMarket(allMarkets[0].id());
    }

    function testEnableMarketShouldRevertWhenTimelockExpirationExceeded(uint128 timelock, uint256 timeElapsed) public {
        timelock = uint128(bound(timelock, 1, MAX_TIMELOCK));
        _submitAndSetTimelock(timelock);

        timeElapsed = bound(timeElapsed, timelock + TIMELOCK_EXPIRATION + 1, type(uint128).max);

        vm.startPrank(RISK_MANAGER);
        vault.submitMarket(allMarkets[0], CAP);

        vm.warp(block.timestamp + timeElapsed);

        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED));
        vault.enableMarket(allMarkets[0].id());
    }

    function testSubmitPendingMarketShouldRevertWhenInconsistenAsset(MarketParams memory marketParamsFuzz) public {
        vm.assume(marketParamsFuzz.borrowableToken != address(borrowableToken));

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.INCONSISTENT_ASSET));
        vault.submitMarket(marketParamsFuzz, 0);
    }

    function testSubmitPendingMarketShouldRevertWhenMarketNotCreated(MarketParams memory marketParamsFuzz) public {
        marketParamsFuzz.borrowableToken = address(borrowableToken);
        (,,,, uint128 lastUpdate,) = morpho.market(marketParamsFuzz.id());
        vm.assume(lastUpdate == 0);

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_CREATED));
        vault.submitMarket(marketParamsFuzz, 0);
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

        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.supplyQueue(1)), Id.unwrap(allMarkets[2].id()));
    }

    function testDisableMarketShouldRevertWhenAlreadyDisabled() public {
        _submitAndEnableMarket(allMarkets[0], CAP);

        vm.startPrank(RISK_MANAGER);
        vault.disableMarket(allMarkets[0].id());

        vm.expectRevert(bytes(ErrorsLib.DISABLE_MARKET_FAILED));
        vault.disableMarket(allMarkets[0].id());
        vm.stopPrank();
    }

    function testDisableMarketShouldRevertWhenMarketIsNotEnabled(MarketParams memory marketParamsFuzz) public {
        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.DISABLE_MARKET_FAILED));
        vault.disableMarket(marketParamsFuzz.id());
    }

    function testSetSupplyQueue() public {
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.supplyQueue(1)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.supplyQueue(2)), Id.unwrap(allMarkets[2].id()));

        Id[] memory supplyQueue = new Id[](3);
        supplyQueue[0] = allMarkets[1].id();
        supplyQueue[1] = allMarkets[2].id();
        supplyQueue[2] = allMarkets[0].id();

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.supplyQueue(1)), Id.unwrap(allMarkets[2].id()));
        assertEq(Id.unwrap(vault.supplyQueue(2)), Id.unwrap(allMarkets[0].id()));
    }

    function testSetSupplyQueueRevertWhenMissingAtLeastOneMarketInTheAllocationList() public {
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

        Id[] memory supplyQueue = new Id[](3);
        supplyQueue[0] = allMarkets[0].id();
        supplyQueue[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_ENABLED));
        vault.setSupplyQueue(supplyQueue);
    }

    function testSetSupplyQueueRevertWhenInvalidLength() public {
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

        Id[] memory supplyQueue1 = new Id[](2);
        supplyQueue1[0] = allMarkets[0].id();
        supplyQueue1[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setSupplyQueue(supplyQueue1);

        Id[] memory supplyQueue2 = new Id[](4);
        supplyQueue2[0] = allMarkets[0].id();
        supplyQueue2[1] = allMarkets[1].id();
        supplyQueue2[2] = allMarkets[2].id();
        supplyQueue2[3] = allMarkets[3].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setSupplyQueue(supplyQueue2);
    }

    function testSetWithdrawQueue() public {
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(1)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(2)), Id.unwrap(allMarkets[2].id()));

        Id[] memory withdrawQueue = new Id[](3);
        withdrawQueue[0] = allMarkets[1].id();
        withdrawQueue[1] = allMarkets[2].id();
        withdrawQueue[2] = allMarkets[0].id();

        vm.prank(ALLOCATOR);
        vault.setWithdrawQueue(withdrawQueue);

        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(1)), Id.unwrap(allMarkets[2].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(2)), Id.unwrap(allMarkets[0].id()));
    }

    function testSetWithdrawQueueRevertWhenMissingAtLeastOneMarketInTheAllocationList() public {
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

        Id[] memory withdrawQueue = new Id[](3);
        withdrawQueue[0] = allMarkets[0].id();
        withdrawQueue[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_ENABLED));
        vault.setWithdrawQueue(withdrawQueue);
    }

    function testSetWithdrawQueueRevertWhenInvalidLength() public {
        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

        Id[] memory withdrawQueue1 = new Id[](2);
        withdrawQueue1[0] = allMarkets[0].id();
        withdrawQueue1[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setWithdrawQueue(withdrawQueue1);

        Id[] memory withdrawQueue2 = new Id[](4);
        withdrawQueue2[0] = allMarkets[0].id();
        withdrawQueue2[1] = allMarkets[1].id();
        withdrawQueue2[2] = allMarkets[2].id();
        withdrawQueue2[3] = allMarkets[3].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.INVALID_LENGTH));
        vault.setWithdrawQueue(withdrawQueue2);
    }

    function testSetCap(uint128 cap) public {
        _submitAndEnableMarket(allMarkets[0], CAP);

        vm.prank(RISK_MANAGER);
        vault.setCap(allMarkets[0], cap);

        assertEq(vault.marketCap(allMarkets[0].id()), cap);
    }

    function testSetCapShouldRevertWhenMarketIsNotEnabled(MarketParams memory marketParamsFuzz) public {
        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_ENABLED));
        vault.setCap(marketParamsFuzz, CAP);
    }
}
