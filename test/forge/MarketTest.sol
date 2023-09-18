// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {stdError} from "@forge-std/StdError.sol";

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

        _setCap(marketParamsFuzz, cap);

        Id id = marketParamsFuzz.id();

        assertEq(vault.cap(id), cap);
        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(id));
        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(id));
    }

    function testAcceptCapShouldRevertWhenTimelockNotElapsed(uint128 timelock, uint256 timeElapsed) public {
        timelock = uint128(bound(timelock, 1, MAX_TIMELOCK));
        _setTimelock(timelock);

        timeElapsed = bound(timeElapsed, 0, timelock - 1);

        vm.startPrank(RISK_MANAGER);
        vault.submitCap(allMarkets[0], CAP);

        vm.warp(block.timestamp + timeElapsed);

        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_ELAPSED));
        vault.acceptCap(allMarkets[0].id());
    }

    function testAcceptCapShouldRevertWhenTimelockExpirationExceeded(uint128 timelock, uint256 timeElapsed) public {
        timelock = uint128(bound(timelock, 1, MAX_TIMELOCK));
        _setTimelock(timelock);

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
