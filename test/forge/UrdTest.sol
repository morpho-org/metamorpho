// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract UrdTest is BaseTest {
    function testSetUrd(address newUrd) public {
        vm.prank(OWNER);
        vault.setUrd(newUrd);
        assertEq(vault.urd(), newUrd);
    }

    function testSetUrdShouldRevertWhenNotOwner(address caller) public {
        vm.assume(caller != vault.owner());

        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setUrd(address(0));
    }

    function testAcceptAsTreasury() public {
        vm.startPrank(OWNER);

        uint256 distributionId = urd.createDistribution(0, bytes32(uint256(1)));

        assertEq(urd.treasuryOf(distributionId), OWNER);

        urd.proposeTreasury(distributionId, address(vault));

        vault.acceptAsTreasury(distributionId);
        assertEq(urd.treasuryOf(distributionId), address(vault));

        vm.stopPrank();
    }

    function testAcceptAsTreasuryRevertWhenNotOwner(address caller) public {
        vm.assume(caller != vault.owner());

        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.acceptAsTreasury(0);
    }

    function testSetUrdAllowance(uint256 totalAmount, uint256 allowanceAmount) public {
        deal(address(collateralToken), address(vault), totalAmount);
        allowanceAmount = bound(allowanceAmount, 0, totalAmount);

        vm.prank(OWNER);
        vault.setUrdAllowance(address(collateralToken), allowanceAmount);
        assertEq(collateralToken.allowance(address(vault), address(urd)), allowanceAmount);
    }

    function testSetUrdAllowanceShouldRevertWhenNotOwner(address caller) public {
        vm.assume(caller != vault.owner());

        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setUrdAllowance(address(collateralToken), 0);
    }
}
