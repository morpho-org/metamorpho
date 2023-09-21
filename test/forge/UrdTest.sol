// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";

import {UrdFactory} from "@universal-rewards-distributor/UrdFactory.sol";
import {IUniversalRewardsDistributor} from "@universal-rewards-distributor/UniversalRewardsDistributor.sol";

import "./helpers/BaseTest.sol";

contract UrdTest is BaseTest {
    using UtilsLib for uint256;

    UrdFactory internal urdFactory;
    IUniversalRewardsDistributor internal rewardsDistributor;

    function setUp() public override {
        super.setUp();

        urdFactory = new UrdFactory();
        vm.prank(OWNER);
        rewardsDistributor = urdFactory.createUrd(OWNER, 0, bytes32(0), bytes32(0), bytes32(0));
    }

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

    function testTransferRewardsBorrowableToken(uint256 rewards, uint256 idle) public {
        idle = bound(idle, 0, MAX_TEST_ASSETS);
        rewards = bound(rewards, 0, MAX_TEST_ASSETS);

        vm.prank(OWNER);
        vault.setRewardsDistributor(address(rewardsDistributor));

        deal(address(borrowableToken), address(vault), rewards);

        borrowableToken.setBalance(address(SUPPLIER), idle);
        vm.prank(SUPPLIER);
        vault.deposit(idle, SUPPLIER);

        assertEq(vault.idle(), idle, "vault.idle()");
        assertEq(
            borrowableToken.balanceOf(address(vault)), idle + rewards, "borrowableToken.balanceOf(address(vault)) 0"
        );

        vault.transferRewards(address(borrowableToken));

        assertEq(borrowableToken.balanceOf(address(vault)), idle, "borrowableToken.balanceOf(address(vault)) 1");
        assertEq(
            borrowableToken.balanceOf(address(rewardsDistributor)),
            rewards,
            "borrowableToken.balanceOf(address(rewardsDistributor))"
        );
    }
}
