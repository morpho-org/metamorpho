// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {stdError} from "@forge-std/StdError.sol";

import {SafeCast} from "@openzeppelin/utils/math/SafeCast.sol";
import "./helpers/IntegrationTest.sol";

contract MarketTest is IntegrationTest {
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;

    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);
    }

    function testMintAllCapsReached() public {
        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(new Id[](0));

        loanToken.setBalance(SUPPLIER, 1);

        vm.prank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);

        vm.expectRevert(ErrorsLib.AllCapsReached.selector);
        vm.prank(SUPPLIER);
        vault.mint(1, RECEIVER);
    }

    function testDepositAllCapsReached() public {
        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(new Id[](0));

        loanToken.setBalance(SUPPLIER, 1);

        vm.prank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);

        vm.expectRevert(ErrorsLib.AllCapsReached.selector);
        vm.prank(SUPPLIER);
        vault.deposit(1, RECEIVER);
    }

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
        vm.prank(CURATOR);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.submitCap(allMarkets[0], CAP);
    }

    function testSetSupplyQueue() public {
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
        for (uint256 i = 3; i < ConstantsLib.MAX_QUEUE_LENGTH - 1; ++i) {
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
        supplyQueue[0] = allMarkets[3].id();

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedMarket.selector, supplyQueue[0]));
        vault.setSupplyQueue(supplyQueue);
    }

    function testUpdateWithdrawQueue() public {
        uint256[] memory indexes = new uint256[](4);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 3;
        indexes[3] = 0;

        Id[] memory expectedWithdrawQueue = new Id[](4);
        expectedWithdrawQueue[0] = allMarkets[0].id();
        expectedWithdrawQueue[1] = allMarkets[1].id();
        expectedWithdrawQueue[2] = allMarkets[2].id();
        expectedWithdrawQueue[3] = idleParams.id();

        vm.expectEmit(address(vault));
        emit EventsLib.SetWithdrawQueue(ALLOCATOR, expectedWithdrawQueue);
        vm.prank(ALLOCATOR);
        vault.updateWithdrawQueue(indexes);

        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(expectedWithdrawQueue[0]));
        assertEq(Id.unwrap(vault.withdrawQueue(1)), Id.unwrap(expectedWithdrawQueue[1]));
        assertEq(Id.unwrap(vault.withdrawQueue(2)), Id.unwrap(expectedWithdrawQueue[2]));
        assertEq(Id.unwrap(vault.withdrawQueue(3)), Id.unwrap(expectedWithdrawQueue[3]));
    }

    function testUpdateWithdrawQueueRemovingDisabledMarket() public {
        _setCap(allMarkets[2], 0);

        uint256[] memory indexes = new uint256[](3);
        indexes[0] = 0;
        indexes[1] = 2;
        indexes[2] = 1;

        Id[] memory expectedWithdrawQueue = new Id[](3);
        expectedWithdrawQueue[0] = idleParams.id();
        expectedWithdrawQueue[1] = allMarkets[1].id();
        expectedWithdrawQueue[2] = allMarkets[0].id();

        vm.expectEmit();
        emit EventsLib.SetWithdrawQueue(ALLOCATOR, expectedWithdrawQueue);
        vm.prank(ALLOCATOR);
        vault.updateWithdrawQueue(indexes);

        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(expectedWithdrawQueue[0]));
        assertEq(Id.unwrap(vault.withdrawQueue(1)), Id.unwrap(expectedWithdrawQueue[1]));
        assertEq(Id.unwrap(vault.withdrawQueue(2)), Id.unwrap(expectedWithdrawQueue[2]));
    }

    function testUpdateWithdrawQueueInvalidIndex() public {
        uint256[] memory indexes = new uint256[](4);
        indexes[0] = 1;
        indexes[1] = 2;
        indexes[2] = 3;
        indexes[3] = 4;

        vm.prank(ALLOCATOR);
        vm.expectRevert(stdError.indexOOBError);
        vault.updateWithdrawQueue(indexes);
    }
}
