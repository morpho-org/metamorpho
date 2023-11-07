// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {stdError} from "@forge-std/StdError.sol";

import {SafeCast} from "@openzeppelin/utils/math/SafeCast.sol";
import "./helpers/IntegrationTest.sol";

contract MarketTest is IntegrationTest {
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;

    function testSubmitCapOverflow(uint256 seed, uint256 cap) public {
        MarketParams memory marketParams = _randomMarketParams(seed);
        cap = bound(cap, uint256(type(uint192).max) + 1, type(uint256).max);

        vm.prank(CURATOR);
        vm.expectRevert(abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, uint8(192), cap));
        vault.submitCap(marketParams, cap);
    }

    function testSubmitCapInconsistentAsset(MarketParams memory marketParams) public {
        vm.assume(marketParams.loanToken != address(loanToken));

        vm.prank(CURATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InconsistentAsset.selector, marketParams.id()));
        vault.submitCap(marketParams, 0);
    }

    function testSubmitCapMarketNotCreated(MarketParams memory marketParams) public {
        marketParams.loanToken = address(loanToken);

        vm.assume(morpho.lastUpdate(marketParams.id()) == 0);

        vm.prank(CURATOR);
        vm.expectRevert(ErrorsLib.MarketNotCreated.selector);
        vault.submitCap(marketParams, 0);
    }

    function testSubmitCapAlreadySet() public {
        _setCap(allMarkets[0], CAP);

        vm.prank(CURATOR);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.submitCap(allMarkets[0], CAP);
    }

    function testSetSupplyQueue() public {
        _setCaps();

        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.supplyQueue(1)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.supplyQueue(2)), Id.unwrap(allMarkets[2].id()));

        Id[] memory supplyQueue = new Id[](2);
        supplyQueue[0] = allMarkets[1].id();
        supplyQueue[1] = allMarkets[2].id();

        vm.expectEmit();
        emit EventsLib.SetSupplyQueue(ALLOCATOR, supplyQueue);
        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.supplyQueue(1)), Id.unwrap(allMarkets[2].id()));
    }

    function testSetSupplyQueueMaxQueueLengthExceeded() public {
        Id[] memory supplyQueue = new Id[](ConstantsLib.MAX_QUEUE_LENGTH + 1);

        vm.prank(ALLOCATOR);
        vm.expectRevert(ErrorsLib.MaxQueueLengthExceeded.selector);
        vault.setSupplyQueue(supplyQueue);
    }

    function testAcceptCapMaxQueueLengthExceeded() public {
        for (uint256 i; i < ConstantsLib.MAX_QUEUE_LENGTH; ++i) {
            _setCap(allMarkets[i], CAP);
        }

        _setTimelock(1 weeks);

        MarketParams memory marketParams = allMarkets[ConstantsLib.MAX_QUEUE_LENGTH];

        vm.prank(CURATOR);
        vault.submitCap(marketParams, CAP);

        vm.warp(block.timestamp + 1 weeks);

        vm.expectRevert(ErrorsLib.MaxQueueLengthExceeded.selector);
        vault.acceptCap(marketParams.id());
    }

    function testSetSupplyQueueUnauthorizedMarket() public {
        Id[] memory supplyQueue = new Id[](1);
        supplyQueue[0] = allMarkets[0].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedMarket.selector, allMarkets[0].id()));
        vault.setSupplyQueue(supplyQueue);
    }

    function testSortWithdrawQueue() public {
        _setCaps();

        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(1)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(2)), Id.unwrap(allMarkets[2].id()));

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 0;

        Id[] memory expectedWithdrawQueue = new Id[](3);
        expectedWithdrawQueue[0] = allMarkets[1].id();
        expectedWithdrawQueue[1] = allMarkets[2].id();
        expectedWithdrawQueue[2] = allMarkets[0].id();

        vm.expectEmit();
        emit EventsLib.SetWithdrawQueue(ALLOCATOR, expectedWithdrawQueue);
        vm.prank(ALLOCATOR);
        vault.updateWithdrawQueue(indexes);

        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(expectedWithdrawQueue[0]));
        assertEq(Id.unwrap(vault.withdrawQueue(1)), Id.unwrap(expectedWithdrawQueue[1]));
        assertEq(Id.unwrap(vault.withdrawQueue(2)), Id.unwrap(expectedWithdrawQueue[2]));
    }

    function testSortWithdrawQueueRemovingDisabledMarket() public {
        _setCaps();

        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(allMarkets[0].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(1)), Id.unwrap(allMarkets[1].id()));
        assertEq(Id.unwrap(vault.withdrawQueue(2)), Id.unwrap(allMarkets[2].id()));

        _setCap(allMarkets[2], 0);

        uint256[] memory indexes = new uint256[](2);
        indexes[0] = 1;
        indexes[1] = 0;

        Id[] memory expectedWithdrawQueue = new Id[](2);
        expectedWithdrawQueue[0] = allMarkets[1].id();
        expectedWithdrawQueue[1] = allMarkets[0].id();

        vm.expectEmit();
        emit EventsLib.SetWithdrawQueue(ALLOCATOR, expectedWithdrawQueue);
        vm.prank(ALLOCATOR);
        vault.updateWithdrawQueue(indexes);

        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(expectedWithdrawQueue[0]));
        assertEq(Id.unwrap(vault.withdrawQueue(1)), Id.unwrap(expectedWithdrawQueue[1]));
    }

    function testSortWithdrawQueueInvalidIndex() public {
        _setCaps();

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 3;

        vm.prank(ALLOCATOR);
        vm.expectRevert(stdError.indexOOBError);
        vault.updateWithdrawQueue(indexes);
    }

    function testSortWithdrawQueueDuplicateMarket() public {
        _setCaps();

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 1;

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.DuplicateMarket.selector, allMarkets[1].id()));
        vault.updateWithdrawQueue(indexes);
    }

    function testSortWithdrawQueueMissingMarketWithNonZeroSupply() public {
        _setCaps();

        loanToken.setBalance(SUPPLIER, 1);

        vm.prank(SUPPLIER);
        vault.deposit(1, RECEIVER);

        uint256[] memory indexes = new uint256[](2);
        indexes[0] = 1;
        indexes[1] = 2;

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidMarketRemoval.selector, allMarkets[0].id()));
        vault.updateWithdrawQueue(indexes);
    }

    function testSortWithdrawQueueMissingMarketWithNonZeroCap() public {
        _setCaps();

        uint256[] memory indexes = new uint256[](2);
        indexes[0] = 0;
        indexes[1] = 2;

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InvalidMarketRemoval.selector, allMarkets[1].id()));
        vault.updateWithdrawQueue(indexes);
    }

    function _setCaps() internal {
        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);
    }
}
