// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";

import "./helpers/BaseTest.sol";

import "forge-std/StdStorage.sol";

contract UrdTest is BaseTest {
    using UtilsLib for uint256;
    using stdStorage for StdStorage;

    function testSetRewardsDistributor(address newRewardsDistributor) public {
        vm.prank(OWNER);
        vault.setRewardsDistributor(newRewardsDistributor);
        assertEq(vault.rewardsDistributor(), newRewardsDistributor);
    }

    function testSetRewardsDistributorShouldRevertWhenNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setRewardsDistributor(address(0));
    }

    function testTransferRewardsNotBorrowableToken(uint256 amount) public {
        vm.prank(OWNER);
        vault.setRewardsDistributor(address(rewardsDistributor));

        deal(address(collateralToken), address(vault), amount);
        assertEq(collateralToken.balanceOf(address(vault)), amount, "collateralToken.balanceOf(address(vault)) 0");

        vault.transferRewards(address(collateralToken));

        assertEq(collateralToken.balanceOf(address(vault)), 0, "collateralToken.balanceOf(address(vault)) 1");
        assertEq(
            collateralToken.balanceOf(address(rewardsDistributor)),
            amount,
            "collateralToken.balanceOf(address(rewardsDistributor))"
        );
    }

    function testTransferRewardsBorrowableToken(uint256 amount, uint256 idle) public {
        amount = bound(amount, idle, type(uint256).max);

        vm.prank(OWNER);
        vault.setRewardsDistributor(address(rewardsDistributor));

        deal(address(borrowableToken), address(vault), amount);
        assertEq(borrowableToken.balanceOf(address(vault)), amount, "borrowableToken.balanceOf(address(vault)) 0");

        // Override idle.
        stdstore.target(address(vault)).sig("idle()").checked_write(idle);
        assertEq(vault.idle(), idle);

        vault.transferRewards(address(borrowableToken));

        assertEq(
            borrowableToken.balanceOf(address(vault)),
            amount - amount.zeroFloorSub(idle),
            "borrowableToken.balanceOf(address(vault)) 1"
        );
        assertEq(
            borrowableToken.balanceOf(address(rewardsDistributor)),
            amount.zeroFloorSub(idle),
            "borrowableToken.balanceOf(address(rewardsDistributor))"
        );
    }
}
