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

    function testSkimNotLoanToken(uint256 amount) public {
        vm.prank(OWNER);
        vault.setRewardsRecipient(address(rewardsDistributor));

        collateralToken.setBalance(address(vault), amount);
        uint256 vaultBalanceBefore = collateralToken.balanceOf(address(vault));
        assertEq(vaultBalanceBefore, amount, "vaultBalanceBefore");

        vm.expectEmit();
        emit EventsLib.TransferRewards(address(this), address(rewardsDistributor), address(collateralToken), amount);
        vault.skim(address(collateralToken));
        uint256 vaultBalanceAfter = collateralToken.balanceOf(address(vault));

        assertEq(vaultBalanceAfter, 0, "vaultBalanceAfter");
        assertEq(
            collateralToken.balanceOf(address(rewardsDistributor)),
            amount,
            "collateralToken.balanceOf(address(rewardsDistributor))"
        );
    }

    function testSkimZeroAddress() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        vault.skim(address(loanToken));
    }
}
