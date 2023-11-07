// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";

import {UrdFactory} from "@universal-rewards-distributor/UrdFactory.sol";
import {IUniversalRewardsDistributor} from "@universal-rewards-distributor/UniversalRewardsDistributor.sol";

import "./helpers/IntegrationTest.sol";

contract UrdTest is IntegrationTest {
    using UtilsLib for uint256;

    UrdFactory internal urdFactory;
    IUniversalRewardsDistributor internal rewardsDistributor;

    function setUp() public override {
        super.setUp();

        urdFactory = new UrdFactory();
        rewardsDistributor = urdFactory.createUrd(OWNER, 0, bytes32(0), bytes32(0), bytes32(0));
    }

    function testSetRewardsRecipient(address newRewardsRecipient) public {
        vm.assume(newRewardsRecipient != vault.rewardsRecipient());

        vm.expectEmit();
        emit EventsLib.SetRewardsRecipient(newRewardsRecipient);
        vm.prank(OWNER);
        vault.setRewardsRecipient(newRewardsRecipient);

        assertEq(vault.rewardsRecipient(), newRewardsRecipient);
    }

    function testAlreadySetRewardsRecipient() public {
        address currentRewardsRecipient = vault.rewardsRecipient();

        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.setRewardsRecipient(currentRewardsRecipient);
    }

    function testSetRewardsRecipientNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.setRewardsRecipient(address(0));
    }

    function testTransferRewardsNotLoanToken(uint256 amount) public {
        vm.prank(OWNER);
        vault.setRewardsRecipient(address(rewardsDistributor));

        collateralToken.setBalance(address(vault), amount);
        uint256 vaultBalanceBefore = collateralToken.balanceOf(address(vault));
        assertEq(vaultBalanceBefore, amount, "vaultBalanceBefore");

        vm.expectEmit(address(vault));
        emit EventsLib.TransferRewards(address(this), address(collateralToken), amount);
        vault.transferRewards(address(collateralToken));
        uint256 vaultBalanceAfter = collateralToken.balanceOf(address(vault));

        assertEq(vaultBalanceAfter, 0, "vaultBalanceAfter");
        assertEq(
            collateralToken.balanceOf(address(rewardsDistributor)),
            amount,
            "collateralToken.balanceOf(address(rewardsDistributor))"
        );
    }

    function testTransferRewardsLoanToken(uint256 rewards, uint256 idle) public {
        idle = bound(idle, 0, MAX_TEST_ASSETS);
        rewards = bound(rewards, 0, MAX_TEST_ASSETS);

        vm.prank(OWNER);
        vault.setRewardsRecipient(address(rewardsDistributor));

        loanToken.setBalance(address(vault), rewards);

        loanToken.setBalance(address(SUPPLIER), idle);
        vm.prank(SUPPLIER);
        vault.deposit(idle, SUPPLIER);

        assertEq(vault.idle(), idle, "vault.idle()");
        uint256 vaultBalanceBefore = loanToken.balanceOf(address(vault));
        assertEq(vaultBalanceBefore, idle + rewards, "vaultBalanceBefore");

        vm.expectEmit(address(vault));
        emit EventsLib.TransferRewards(address(this), address(loanToken), rewards);
        vault.transferRewards(address(loanToken));
        uint256 vaultBalanceAfter = loanToken.balanceOf(address(vault));

        assertEq(vaultBalanceAfter, idle, "vaultBalanceAfter");
        assertEq(
            loanToken.balanceOf(address(rewardsDistributor)),
            rewards,
            "loanToken.balanceOf(address(rewardsDistributor))"
        );
    }

    function testTransferRewardsZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        vault.transferRewards(address(loanToken));
    }
}
