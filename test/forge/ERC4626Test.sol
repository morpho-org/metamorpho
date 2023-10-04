// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

contract ERC4626Test is BaseTest {
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
    }

    function testMint(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        uint256 shares = vault.convertToShares(assets);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        uint256 deposited = vault.mint(shares, ONBEHALF);

        assertGt(deposited, 0, "deposited");
        assertEq(vault.balanceOf(ONBEHALF), shares, "balanceOf(ONBEHALF)");
        assertEq(morpho.expectedSupplyBalance(allMarkets[0], address(vault)), assets, "expectedSupplyBalance(vault)");
    }

    function testDeposit(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(assets, ONBEHALF);

        assertGt(shares, 0, "shares");
        assertEq(vault.balanceOf(ONBEHALF), shares, "balanceOf(ONBEHALF)");
        assertEq(morpho.expectedSupplyBalance(allMarkets[0], address(vault)), assets, "expectedSupplyBalance(vault)");
    }

    function testRedeemTooMuch(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        vm.prank(ONBEHALF);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        vault.redeem(shares + 1, RECEIVER, ONBEHALF);
    }

    function testWithdrawAll(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        uint256 minted = vault.deposit(assets, ONBEHALF);

        assertEq(vault.maxWithdraw(ONBEHALF), assets, "maxWithdraw(ONBEHALF)");

        vm.prank(ONBEHALF);
        uint256 shares = vault.withdraw(assets, RECEIVER, ONBEHALF);

        assertEq(shares, minted, "shares");
        assertEq(vault.balanceOf(ONBEHALF), 0, "balanceOf(ONBEHALF)");
        assertEq(loanToken.balanceOf(RECEIVER), assets, "loanToken.balanceOf(RECEIVER)");
        assertEq(morpho.expectedSupplyBalance(allMarkets[0], address(vault)), 0, "expectedSupplyBalance(vault)");
    }

    function testRedeemAll(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 minted = vault.deposit(deposited, ONBEHALF);

        assertEq(vault.maxRedeem(ONBEHALF), minted, "maxRedeem(ONBEHALF)");

        vm.prank(ONBEHALF);
        uint256 assets = vault.redeem(minted, RECEIVER, ONBEHALF);

        assertEq(assets, deposited, "assets");
        assertEq(vault.balanceOf(ONBEHALF), 0, "balanceOf(ONBEHALF)");
        assertEq(loanToken.balanceOf(RECEIVER), deposited, "loanToken.balanceOf(RECEIVER)");
        assertEq(morpho.expectedSupplyBalance(allMarkets[0], address(vault)), 0, "expectedSupplyBalance(vault)");
    }

    function testRedeemNotDeposited(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        vm.prank(SUPPLIER);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        vault.redeem(shares, SUPPLIER, SUPPLIER);
    }

    function testRedeemNotApproved(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        vm.prank(RECEIVER);
        vm.expectRevert("ERC20: insufficient allowance");
        vault.redeem(shares, RECEIVER, ONBEHALF);
    }

    function testWithdrawNotApproved(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        vm.prank(RECEIVER);
        vm.expectRevert("ERC20: insufficient allowance");
        vault.withdraw(assets, RECEIVER, ONBEHALF);
    }

    function testTransferFrom(uint256 deposited, uint256 toTransfer) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        toTransfer = bound(toTransfer, 0, shares);

        vm.prank(ONBEHALF);
        vault.approve(SUPPLIER, toTransfer);

        vm.prank(SUPPLIER);
        vault.transferFrom(ONBEHALF, RECEIVER, toTransfer);

        assertEq(vault.balanceOf(ONBEHALF), shares - toTransfer, "balanceOf(ONBEHALF)");
        assertEq(vault.balanceOf(RECEIVER), toTransfer, "balanceOf(RECEIVER)");
        assertEq(vault.balanceOf(SUPPLIER), 0, "balanceOf(SUPPLIER)");
    }

    function testTransferFromNotApproved(uint256 deposited, uint256 amount) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        amount = bound(amount, 0, shares);

        vm.prank(SUPPLIER);
        vm.expectRevert("ERC20: insufficient allowance");
        vault.transferFrom(ONBEHALF, RECEIVER, shares);
    }

    function testWithdrawMoreThanBalanceButLessThanTotalAssets(uint256 deposited, uint256 assets) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assets = bound(assets, deposited + 1, type(uint256).max / (deposited + 10 ** DECIMALS_OFFSET));

        uint256 toAdd = assets - deposited + 1;
        loanToken.setBalance(SUPPLIER, toAdd);

        vm.prank(SUPPLIER);
        vault.deposit(toAdd, SUPPLIER);

        vm.prank(ONBEHALF);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        vault.withdraw(assets, RECEIVER, ONBEHALF);
    }

    function testWithdrawMoreThanTotalAssets(uint256 deposited, uint256 assets) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assets = bound(assets, deposited + 1, type(uint256).max / (deposited + 10 ** DECIMALS_OFFSET));

        vm.prank(ONBEHALF);
        vm.expectRevert(ErrorsLib.WithdrawMorphoFailed.selector);
        vault.withdraw(assets, RECEIVER, ONBEHALF);
    }

    function testWithdrawMoreThanBalanceButLessThanLiquidity(uint256 deposited, uint256 assets) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assets = bound(assets, deposited + 1, type(uint256).max / (deposited + 10 ** DECIMALS_OFFSET));

        collateralToken.setBalance(BORROWER, type(uint128).max);

        // Borrow liquidity.
        vm.startPrank(BORROWER);
        morpho.supplyCollateral(allMarkets[0], type(uint128).max, BORROWER, hex"");
        morpho.borrow(allMarkets[0], 1, 0, BORROWER, BORROWER);
        vm.stopPrank();

        vm.prank(ONBEHALF);
        vm.expectRevert(ErrorsLib.WithdrawMorphoFailed.selector);
        vault.withdraw(assets, RECEIVER, ONBEHALF);
    }

    function testTransfer(uint256 deposited, uint256 toTransfer) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 minted = vault.deposit(deposited, ONBEHALF);

        toTransfer = bound(toTransfer, 0, minted);

        vm.prank(ONBEHALF);
        vault.transfer(RECEIVER, toTransfer);

        assertEq(vault.balanceOf(SUPPLIER), 0, "balanceOf(SUPPLIER)");
        assertEq(vault.balanceOf(ONBEHALF), minted - toTransfer, "balanceOf(ONBEHALF)");
        assertEq(vault.balanceOf(RECEIVER), toTransfer, "balanceOf(RECEIVER)");
    }
}
