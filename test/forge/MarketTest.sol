// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {stdError} from "@forge-std/StdError.sol";

import "./helpers/BaseTest.sol";

contract MarketTest is BaseTest {
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;

    function testSubmitCap(uint256 seed, uint256 cap) public {
        MarketParams memory marketParams = allMarkets[seed % allMarkets.length];
        cap = bound(cap, 1, type(uint192).max);

        vm.prank(RISK_MANAGER);
        vault.submitCap(marketParams, cap);

        (uint192 newCap, uint64 withdrawRank) = vault.config(marketParams.id());

        assertEq(newCap, cap, "newCap");
        assertEq(withdrawRank, 1, "withdrawRank");
    }

    function testSubmitCapOverflow(uint256 seed, uint256 cap) public {
        MarketParams memory marketParams = allMarkets[seed % allMarkets.length];

        cap = bound(cap, uint256(type(uint192).max) + 1, type(uint256).max);

        vm.prank(RISK_MANAGER);
        vm.expectRevert("SafeCast: value doesn't fit in 192 bits");
        vault.submitCap(marketParams, cap);
    }

    function testSubmitCapInconsistentAsset(MarketParams memory marketParams) public {
        vm.assume(marketParams.borrowableToken != address(borrowableToken));

        vm.prank(RISK_MANAGER);
        vm.expectRevert(bytes(ErrorsLib.INCONSISTENT_ASSET));
        vault.submitCap(marketParams, 0);
    }

    function testSubmitCapMarketNotCreated(MarketParams memory marketParams) public {
        marketParams.borrowableToken = address(borrowableToken);

        vm.assume(morpho.lastUpdate(marketParams.id()) == 0);

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
