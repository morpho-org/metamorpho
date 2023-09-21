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
        rewardsDistributor = urdFactory.createUrd(OWNER, 0, bytes32(0), bytes32(0), bytes32(0));
    }

    function testSetRewardsDistributor(address newRewardsDistributor) public {
        vm.prank(OWNER);
        vault.setRewardsDistributor(newRewardsDistributor);
        assertEq(vault.rewardsDistributor(), newRewardsDistributor);
    }

    function testSetRewardsDistributorNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setRewardsDistributor(address(0));
    }

    function testTransferRewardsNotBorrowableToken(uint256 amount) public {
        vm.prank(OWNER);
        vault.setRewardsDistributor(address(rewardsDistributor));

        collateralToken.setBalance(address(vault), amount);
        uint256 vaultBalanceBefore = collateralToken.balanceOf(address(vault));
        assertEq(vaultBalanceBefore, amount, "vaultBalanceBefore");

        vault.transferRewards(address(collateralToken));
        uint256 vaultBalanceAfter = collateralToken.balanceOf(address(vault));

        assertEq(vaultBalanceAfter, 0, "vaultBalanceAfter");
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

        borrowableToken.setBalance(address(vault), rewards);

        borrowableToken.setBalance(address(SUPPLIER), idle);
        vm.prank(SUPPLIER);
        vault.deposit(idle, SUPPLIER);

        assertEq(vault.idle(), idle, "vault.idle()");
        uint256 vaultBalanceBefore = borrowableToken.balanceOf(address(vault));
        assertEq(vaultBalanceBefore, idle + rewards, "vaultBalanceBefore");

        vault.transferRewards(address(borrowableToken));
        uint256 vaultBalanceAfter = borrowableToken.balanceOf(address(vault));

        assertEq(vaultBalanceAfter, idle, "vaultBalanceAfter");
        assertEq(
            borrowableToken.balanceOf(address(rewardsDistributor)),
            rewards,
            "borrowableToken.balanceOf(address(rewardsDistributor))"
        );
    }
}
