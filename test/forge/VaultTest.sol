// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

import "./BaseTest.sol";

contract VaultTest is BaseTest {
    using MorphoBalancesLib for Morpho;
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

        _submitAndEnableMarket(allMarkets[0], CAP);
    }

    function tesMint(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);
        uint256 shares = vault.convertToShares(amount);

        vm.prank(SUPPLIER);
        vault.mint(shares, RECEIVER);

        uint256 totalBalanceAfter = morpho.expectedSupplyBalance(allMarkets[0], address(vault));

        assertEq(vault.balanceOf(RECEIVER), shares, "balance");
        assertGt(shares, 0, "shares is zero");
        assertEq(totalBalanceAfter, amount, "totalBalance");
    }

    function testDeposit(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.prank(SUPPLIER);
        vault.deposit(amount, RECEIVER);

        uint256 totalBalanceAfter = morpho.expectedSupplyBalance(allMarkets[0], address(vault));

        assertGt(vault.balanceOf(RECEIVER), 0, "balance is zero");
        assertEq(totalBalanceAfter, amount, "totalBalance");
    }

    function testShouldNotRedeemTooMuch(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(amount, RECEIVER);

        vm.prank(RECEIVER);
        vm.expectRevert(bytes(ErrorsLib.WITHDRAW_ORDER_FAILED));
        vault.redeem(shares + 1, RECEIVER, RECEIVER);
    }

    function testWithdrawAll(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        uint256 totalBalanceBefore = morpho.expectedSupplyBalance(allMarkets[0], address(vault));

        vm.prank(SUPPLIER);
        vault.deposit(amount, RECEIVER);

        vm.startPrank(RECEIVER);
        vault.withdraw(vault.maxWithdraw(RECEIVER), RECEIVER, RECEIVER);
        vm.stopPrank();

        uint256 totalBalanceAfter = morpho.expectedSupplyBalance(allMarkets[0], address(vault));

        assertEq(vault.balanceOf(RECEIVER), 0, "balance not zero");
        assertEq(ERC20(borrowableToken).balanceOf(RECEIVER), amount, "amount withdrawn != amount deposited");
        assertEq(totalBalanceAfter, totalBalanceBefore, "totalBalance");
    }

    function testRedeemAll(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(amount, RECEIVER);

        vm.prank(RECEIVER);
        vault.redeem(shares, RECEIVER, RECEIVER);

        uint256 totalBalanceAfter = morpho.expectedSupplyBalance(allMarkets[0], address(vault));

        assertEq(ERC20(borrowableToken).balanceOf(RECEIVER), amount, "amount withdrawn != amount deposited");
        assertEq(vault.balanceOf(SUPPLIER), 0, "balance not zero");
        assertEq(totalBalanceAfter, 0, "totalBalance");
    }

    function testShouldNotRedeemWhenNotDeposited(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.prank(SUPPLIER);
        vm.expectRevert(bytes(ErrorsLib.WITHDRAW_ORDER_FAILED));
        vault.redeem(amount, SUPPLIER, SUPPLIER);
    }

    function testShouldNotRedeemIfNotApproved(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(amount, SUPPLIER);

        vm.prank(RECEIVER);
        vm.expectRevert("ERC20: insufficient allowance");
        vault.redeem(shares, RECEIVER, SUPPLIER);
    }

    function testShouldNotWithdrawIfNotApproved(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        vm.prank(RECEIVER);
        vm.expectRevert("ERC20: insufficient allowance");
        vault.withdraw(amount, RECEIVER, SUPPLIER);
    }

    function testTransferFrom(uint256 amount, uint256 toApprove) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.startPrank(SUPPLIER);
        uint256 shares = vault.deposit(amount, SUPPLIER);
        toApprove = bound(toApprove, 0, shares);
        vault.approve(RECEIVER, toApprove);
        vm.stopPrank();

        vm.prank(RECEIVER);
        vault.transferFrom(SUPPLIER, RECEIVER, toApprove);

        assertEq(vault.balanceOf(SUPPLIER), amount - toApprove, "balance supplier");
        assertEq(vault.balanceOf(RECEIVER), toApprove, "balance receiver");
    }

    function testShouldNotTransferFromIfNotApproved(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(amount, SUPPLIER);

        vm.prank(RECEIVER);
        vm.expectRevert("ERC20: insufficient allowance");
        vault.transferFrom(SUPPLIER, RECEIVER, shares);
    }

    function testShouldNotWithdrawTooMuch(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        vm.prank(SUPPLIER);
        vm.expectRevert(bytes(ErrorsLib.WITHDRAW_ORDER_FAILED));
        vault.withdraw(amount + 1, SUPPLIER, SUPPLIER);
    }

    function testTransfer(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        uint256 balance = vault.balanceOf(SUPPLIER);
        vm.prank(SUPPLIER);
        vault.transfer(RECEIVER, balance);

        assertEq(vault.balanceOf(SUPPLIER), 0);
        assertEq(vault.balanceOf(RECEIVER), balance);
    }
}
