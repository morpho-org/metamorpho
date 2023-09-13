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
        vault.submitMarket(allMarkets[0], CAP);

        vm.expectRevert(bytes(ErrorsLib.NOT_RISK_MANAGER));
        vault.enableMarket(allMarkets[0].id());

        vm.expectRevert(bytes(ErrorsLib.NOT_RISK_MANAGER));
        vault.setCap(allMarkets[0], CAP);

        vm.expectRevert(bytes(ErrorsLib.NOT_RISK_MANAGER));
        vault.disableMarket(allMarkets[0].id());

        vm.stopPrank();
    }

    function testAllocatorFunctionsShouldRevertWhenNotAllocatorAndNotRiskManagerAndNotOwner(address caller) public {
        vm.assume(caller != vault.owner() && !vault.isRiskManager(caller) && !vault.isAllocator(caller));
        vm.startPrank(caller);

        Id[] memory order;
        MarketAllocation[] memory allocation;

        vm.expectRevert(bytes(ErrorsLib.NOT_ALLOCATOR));
        vault.setSupplyAllocationOrder(order);

        vm.expectRevert(bytes(ErrorsLib.NOT_ALLOCATOR));
        vault.setWithdrawAllocationOrder(order);

        vm.expectRevert(bytes(ErrorsLib.NOT_ALLOCATOR));
        vault.reallocate(allocation, allocation);

        vm.stopPrank();
    }

    function testRiskManagerOrOwnerShouldTriggerRiskManagerFunctions() public {
        vm.startPrank(OWNER);
        vault.submitMarket(allMarkets[0], CAP);
        vault.enableMarket(allMarkets[0].id());
        vault.setCap(allMarkets[0], CAP);
        vault.disableMarket(allMarkets[0].id());
        vm.stopPrank();

        vm.startPrank(RISK_MANAGER);
        vault.submitMarket(allMarkets[1], CAP);
        vault.enableMarket(allMarkets[1].id());
        vault.setCap(allMarkets[1], CAP);
        vault.disableMarket(allMarkets[1].id());
        vm.stopPrank();
    }

    function testAllocatorOrRiskManagerOrOwnerShouldTriggerAllocatorFunctions() public {
        Id[] memory order = new Id[](2);
        order[0] = idleMarket.id();
        order[1] = allMarkets[0].id();
        MarketAllocation[] memory allocation;

        _submitAndEnableMarket(allMarkets[0], CAP);

        vm.startPrank(OWNER);
        vault.setSupplyAllocationOrder(order);
        vault.setWithdrawAllocationOrder(order);
        vault.reallocate(allocation, allocation);
        vm.stopPrank();

        vm.startPrank(RISK_MANAGER);
        vault.setSupplyAllocationOrder(order);
        vault.setWithdrawAllocationOrder(order);
        vault.reallocate(allocation, allocation);
        vm.stopPrank();

        vm.startPrank(ALLOCATOR);
        vault.setSupplyAllocationOrder(order);
        vault.setWithdrawAllocationOrder(order);
        vault.reallocate(allocation, allocation);
        vm.stopPrank();
    }
}
