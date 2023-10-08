// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

contract RoleTest is BaseTest {
    using MarketParamsLib for MarketParams;

    function testSetRiskManager() public {
        address newRiskManager = _addrFromHashedString("RiskManager2");

        vm.prank(OWNER);
        vault.setRiskManager(newRiskManager);

        assertEq(vault.riskManager(), newRiskManager, "riskManager");
    }

    function testSetRiskManagerShouldRevertAlreadySet() public {
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.setRiskManager(RISK_MANAGER);
    }

    function testSetAllocator() public {
        address newAllocator = _addrFromHashedString("Allocator2");

        vm.prank(OWNER);
        vault.setIsAllocator(newAllocator, true);

        assertTrue(vault.isAllocator(newAllocator), "isAllocator");
    }

    function testUnsetAllocator() public {
        vm.prank(OWNER);
        vault.setIsAllocator(ALLOCATOR, false);

        assertFalse(vault.isAllocator(ALLOCATOR), "isAllocator");
    }

    function testSetAllocatorShouldRevertAlreadySet() public {
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.setIsAllocator(ALLOCATOR, true);
    }

    function testOwnerFunctionsShouldRevertWhenNotOwner(address caller) public {
        vm.assume(caller != vault.owner());

        vm.startPrank(caller);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.setRiskManager(caller);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.setIsAllocator(caller, true);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.submitTimelock(1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.submitFee(1);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.submitGuardian(address(1));

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(caller)));
        vault.setFeeRecipient(caller);

        vm.stopPrank();
    }

    function testRiskManagerFunctionsShouldRevertWhenNotRiskManagerAndNotOwner(address caller) public {
        vm.assume(caller != vault.owner() && caller != vault.riskManager());

        vm.startPrank(caller);

        vm.expectRevert(ErrorsLib.NotRiskManager.selector);
        vault.submitCap(allMarkets[0], CAP);

        vm.stopPrank();
    }

    function testAllocatorFunctionsShouldRevertWhenNotAllocatorAndNotRiskManagerAndNotOwner(address caller) public {
        vm.assume(!vault.isAllocator(caller));

        vm.startPrank(caller);

        Id[] memory supplyQueue;
        MarketAllocation[] memory allocation;
        uint256[] memory withdrawQueueFromRanks;

        vm.expectRevert(ErrorsLib.NotAllocator.selector);
        vault.setSupplyQueue(supplyQueue);

        vm.expectRevert(ErrorsLib.NotAllocator.selector);
        vault.sortWithdrawQueue(withdrawQueueFromRanks);

        vm.expectRevert(ErrorsLib.NotAllocator.selector);
        vault.reallocate(allocation, allocation);

        vm.stopPrank();
    }

    function testRiskManagerOrOwnerShouldTriggerRiskManagerFunctions() public {
        vm.prank(OWNER);
        vault.submitCap(allMarkets[0], CAP);

        vm.prank(RISK_MANAGER);
        vault.submitCap(allMarkets[1], CAP);
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
