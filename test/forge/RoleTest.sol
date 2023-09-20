// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

contract RoleTest is BaseTest {
    using MarketParamsLib for MarketParams;

    function testOwnerFunctionsShouldRevertWhenNotOwner(address caller) public {
        vm.assume(caller != vault.owner());
        vm.startPrank(caller);

        vm.expectRevert("Ownable: caller is not the owner");
        vault.submitTimelock(TIMELOCK);

        vm.expectRevert("Ownable: caller is not the owner");
        vault.acceptTimelock();

        vm.expectRevert("Ownable: caller is not the owner");
        vault.setIsRiskManager(caller, true);

        vm.expectRevert("Ownable: caller is not the owner");
        vault.setIsAllocator(caller, true);

        vm.expectRevert("Ownable: caller is not the owner");
        vault.submitFee(1);

        vm.expectRevert("Ownable: caller is not the owner");
        vault.acceptFee();

        vm.expectRevert("Ownable: caller is not the owner");
        vault.setFeeRecipient(caller);

        vm.stopPrank();
    }

    function testRiskManagerFunctionsShouldRevertWhenNotRiskManagerAndNotOwner(address caller) public {
        vm.assume(caller != vault.owner() && !vault.isRiskManager(caller));
        vm.startPrank(caller);

        vm.expectRevert(bytes(ErrorsLib.NOT_RISK_MANAGER));
        vault.submitCap(allMarkets[0], CAP);

        vm.expectRevert(bytes(ErrorsLib.NOT_RISK_MANAGER));
        vault.acceptCap(allMarkets[0].id());

        vm.stopPrank();
    }

    function testAllocatorFunctionsShouldRevertWhenNotAllocatorAndNotRiskManagerAndNotOwner(address caller) public {
        vm.assume(caller != vault.owner() && !vault.isRiskManager(caller) && !vault.isAllocator(caller));
        vm.startPrank(caller);

        Id[] memory supplyQueue;
        MarketAllocation[] memory allocation;
        uint256[] memory withdrawQueueFromRanks;

        vm.expectRevert(bytes(ErrorsLib.NOT_ALLOCATOR));
        vault.setSupplyQueue(supplyQueue);

        vm.expectRevert(bytes(ErrorsLib.NOT_ALLOCATOR));
        vault.sortWithdrawQueue(withdrawQueueFromRanks);

        vm.expectRevert(bytes(ErrorsLib.NOT_ALLOCATOR));
        vault.reallocate(allocation, allocation);

        vm.stopPrank();
    }

    function testRiskManagerOrOwnerShouldTriggerRiskManagerFunctions() public {
        vm.prank(OWNER);
        vault.submitCap(allMarkets[0], CAP);

        vm.warp(block.timestamp + vault.timelock());

        vm.prank(OWNER);
        vault.acceptCap(allMarkets[0].id());

        vm.prank(RISK_MANAGER);
        vault.submitCap(allMarkets[1], CAP);

        vm.warp(block.timestamp + vault.timelock());

        vm.prank(RISK_MANAGER);
        vault.acceptCap(allMarkets[1].id());
    }

    function testAllocatorOrRiskManagerOrOwnerShouldTriggerAllocatorFunctions() public {
        _setCap(allMarkets[0], CAP);

        Id[] memory supplyQueue = new Id[](1);
        supplyQueue[0] = allMarkets[0].id();

        uint256[] memory withdrawQueueFromRanks = new uint256[](1);
        withdrawQueueFromRanks[0] = 0;

        MarketAllocation[] memory allocation;

        vm.startPrank(OWNER);
        vault.setSupplyQueue(supplyQueue);
        vault.sortWithdrawQueue(withdrawQueueFromRanks);
        vault.reallocate(allocation, allocation);
        vm.stopPrank();

        vm.startPrank(RISK_MANAGER);
        vault.setSupplyQueue(supplyQueue);
        vault.sortWithdrawQueue(withdrawQueueFromRanks);
        vault.reallocate(allocation, allocation);
        vm.stopPrank();

        vm.startPrank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);
        vault.sortWithdrawQueue(withdrawQueueFromRanks);
        vault.reallocate(allocation, allocation);
        vm.stopPrank();
    }
}
