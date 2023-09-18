// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {stdError} from "@forge-std/StdError.sol";

import "./helpers/BaseTest.sol";

contract MarketTest is BaseTest {
    using MarketParamsLib for MarketParams;

    function testSubmitCap(uint256 seed, uint256 cap) public {
        MarketParams memory marketParams = allMarkets[seed % allMarkets.length];
        cap = bound(cap, 1, type(uint192).max);

        vm.prank(RISK_MANAGER);
        vault.submitCap(marketParams, cap);

        (uint192 value, uint64 timestamp) = vault.pendingCap(marketParams.id());

        assertEq(value, cap);
        assertEq(timestamp, block.timestamp);
    }

    function testSubmitCapOverflow(uint256 seed, uint256 cap) public {
        MarketParams memory marketParams = allMarkets[seed % allMarkets.length];

        cap = bound(cap, uint256(type(uint192).max) + 1, type(uint256).max);

        vm.prank(RISK_MANAGER);
        vm.expectRevert("SafeCast: value doesn't fit in 192 bits");
        vault.submitCap(marketParams, cap);
    }

    function testSubmitCapZeroNoTimelock(uint256 seed, uint256 cap) public {
        MarketParams memory marketParams = allMarkets[seed % allMarkets.length];
        cap = bound(cap, 1, type(uint192).max);

        _setCap(marketParams, cap);

        vm.prank(RISK_MANAGER);
        vault.submitCap(marketParams, 0);

        assertEq(vault.cap(marketParams.id()), 0);
    }

    function testAcceptCap(uint256 seed, uint256 cap) public {
        MarketParams memory marketParams = allMarkets[seed % allMarkets.length];
        cap = bound(cap, 0, type(uint192).max);

        _setCap(marketParams, cap);

        Id id = marketParams.id();

        assertEq(vault.cap(id), cap);
        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(id));
        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(id));
    }

    function testAcceptCapTimelockNotElapsed(uint256 timelock, uint256 timeElapsed) public {
        timelock = bound(timelock, 1, MAX_TIMELOCK);

        vm.assume(timelock != vault.timelock());

        _setTimelock(timelock);

        timeElapsed = bound(timeElapsed, 0, timelock - 1);

        vm.prank(RISK_MANAGER);
        vault.submitCap(allMarkets[0], CAP);

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_ELAPSED));
        vault.acceptCap(allMarkets[0].id());
    }

    function testAcceptCapTimelockExpirationExceeded(uint256 timelock, uint256 timeElapsed) public {
        timelock = bound(timelock, 1, MAX_TIMELOCK);

        vm.assume(timelock != vault.timelock());

        _setTimelock(timelock);

        timeElapsed = bound(timeElapsed, timelock + TIMELOCK_EXPIRATION + 1, type(uint64).max);

        vm.startPrank(RISK_MANAGER);
        vault.submitCap(allMarkets[0], CAP);

        vm.warp(block.timestamp + timeElapsed);

        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED));
        vault.acceptCap(allMarkets[0].id());
    }

    function testSubmitCapInconsistentAsset(MarketParams memory marketParams) public {
        vm.assume(marketParams.borrowableToken != address(borrowableToken));

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.INCONSISTENT_ASSET));
        vault.submitCap(marketParams, 0);
    }

    function testSubmitCapMarketNotCreated(MarketParams memory marketParams) public {
        marketParams.borrowableToken = address(borrowableToken);
        (,,,, uint256 lastUpdate,) = morpho.market(marketParams.id());
        vm.assume(lastUpdate == 0);

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.MARKET_NOT_CREATED));
        vault.submitCap(marketParams, 0);
    }

    function testSetSupplyQueue() public {
        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);

        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.supplyQueue(1)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.supplyQueue(2)), Id.unwrap(allMarkets[2].id()));

        Id[] memory supplyQueue = new Id[](2);
        supplyQueue[0] = allMarkets[1].id();
        supplyQueue[1] = allMarkets[2].id();

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.supplyQueue(1)), Id.unwrap(allMarkets[2].id()));
    }

    function testSortWithdrawQueue() public {
        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);

        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(1)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(2)), Id.unwrap(allMarkets[2].id()));

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 0;

        vm.prank(ALLOCATOR);
        vault.sortWithdrawQueue(indexes);

        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(1)), Id.unwrap(allMarkets[2].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(2)), Id.unwrap(allMarkets[0].id()));
    }

    function testSortWithdrawQueueInvalidIndex() public {
        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 3;

        vm.prank(ALLOCATOR);
        vm.expectRevert(stdError.indexOOBError);
        vault.sortWithdrawQueue(indexes);
    }

    function testSortWithdrawQueueDuplicateMarket() public {
        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 1;

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.DUPLICATE_MARKET));
        vault.sortWithdrawQueue(indexes);
    }

    function testSortWithdrawQueueMissingMarket() public {
        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);

        borrowableToken.setBalance(SUPPLIER, 1);

        vm.prank(SUPPLIER);
        vault.deposit(1, RECEIVER);

        uint256[] memory indexes = new uint256[](2);
        indexes[0] = 1;
        indexes[1] = 2;

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.MISSING_MARKET));
        vault.sortWithdrawQueue(indexes);
    }
}
