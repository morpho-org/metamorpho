// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

contract MarketTest is BaseTest {
    using MarketParamsLib for MarketParams;

    function testSubmitCap(uint256 seed, uint192 cap) public {
        MarketParams memory marketParamsFuzz = allMarkets[seed % allMarkets.length];

        vm.prank(RISK_MANAGER);
        vault.submitCap(marketParamsFuzz, cap);

        (uint192 value, uint64 timestamp) = vault.pendingCap(marketParamsFuzz.id());
        assertEq(value, cap);
        assertEq(timestamp, block.timestamp);
    }

    function testAcceptCap(uint256 seed, uint128 cap) public {
        MarketParams memory marketParamsFuzz = allMarkets[seed % allMarkets.length];

        _submitAndAcceptCap(marketParamsFuzz, cap);

        Id id = marketParamsFuzz.id();

        assertEq(vault.cap(id), cap);
        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(id));
        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(id));
    }

    function testAcceptCapShouldRevertWhenTimelockNotElapsed(uint128 timelock, uint256 timeElapsed) public {
        timelock = uint128(bound(timelock, 1, MAX_TIMELOCK));
        _submitAndSetTimelock(timelock);

        timeElapsed = bound(timeElapsed, 0, timelock - 1);

        vm.startPrank(RISK_MANAGER);
        vault.submitCap(allMarkets[0], CAP);

        vm.warp(block.timestamp + timeElapsed);

        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_ELAPSED));
        vault.acceptCap(allMarkets[0].id());
    }

    function testAcceptCapShouldRevertWhenTimelockExpirationExceeded(uint128 timelock, uint256 timeElapsed) public {
        timelock = uint128(bound(timelock, 1, MAX_TIMELOCK));
        _submitAndSetTimelock(timelock);

        timeElapsed = bound(timeElapsed, timelock + TIMELOCK_EXPIRATION + 1, type(uint128).max);

        vm.startPrank(RISK_MANAGER);
        vault.submitCap(allMarkets[0], CAP);

        vm.warp(block.timestamp + timeElapsed);

        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED));
        vault.acceptCap(allMarkets[0].id());
    }

    function testSubmitCapRevertInconsistentAsset(MarketParams memory marketParamsFuzz) public {
        vm.assume(marketParamsFuzz.borrowableToken != address(borrowableToken));

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.INCONSISTENT_ASSET));
        vault.submitCap(marketParamsFuzz, 0);
    }

    function testSubmitCapRevertMarketNotCreated(MarketParams memory marketParamsFuzz) public {
        marketParamsFuzz.borrowableToken = address(borrowableToken);
        (,,,, uint128 lastUpdate,) = morpho.market(marketParamsFuzz.id());
        vm.assume(lastUpdate == 0);

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_CREATED));
        vault.submitCap(marketParamsFuzz, 0);
    }

    function testSetSupplyQueue() public {
        _submitAndAcceptCap(allMarkets[0], CAP);
        _submitAndAcceptCap(allMarkets[1], CAP);
        _submitAndAcceptCap(allMarkets[2], CAP);

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
        _submitAndAcceptCap(allMarkets[0], CAP);
        _submitAndAcceptCap(allMarkets[1], CAP);
        _submitAndAcceptCap(allMarkets[2], CAP);

        Id[] memory supplyQueue = new Id[](3);
        supplyQueue[0] = allMarkets[0].id();
        supplyQueue[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_ENABLED));
        vault.setSupplyQueue(supplyQueue);
    }

    function testSetSupplyQueueRevertWhenInvalidLength() public {
        _submitAndAcceptCap(allMarkets[0], CAP);
        _submitAndAcceptCap(allMarkets[1], CAP);
        _submitAndAcceptCap(allMarkets[2], CAP);

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
        _submitAndAcceptCap(allMarkets[0], CAP);
        _submitAndAcceptCap(allMarkets[1], CAP);
        _submitAndAcceptCap(allMarkets[2], CAP);

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
        _submitAndAcceptCap(allMarkets[0], CAP);
        _submitAndAcceptCap(allMarkets[1], CAP);
        _submitAndAcceptCap(allMarkets[2], CAP);

        Id[] memory withdrawQueue = new Id[](3);
        withdrawQueue[0] = allMarkets[0].id();
        withdrawQueue[1] = allMarkets[1].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_ENABLED));
        vault.setWithdrawQueue(withdrawQueue);
    }

    function testSetWithdrawQueueRevertWhenInvalidLength() public {
        _submitAndAcceptCap(allMarkets[0], CAP);
        _submitAndAcceptCap(allMarkets[1], CAP);
        _submitAndAcceptCap(allMarkets[2], CAP);

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
}
