// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract FeeTest is BaseTest {
    using Math for uint256;
    using MarketParamsLib for MarketParams;

    uint256 internal constant FEE = 0.1 ether; // 10%

    function setUp() public override {
        super.setUp();

        _submitAndEnableMarket(allMarkets[0], CAP);

        irm.setRate(0.1 ether); // 10% APY.
    }

    function _setFee() internal {
        vm.startPrank(OWNER);
        vault.submitPendingFee(FEE);
        vault.setFee();
        vault.setFeeRecipient(FEE_RECIPIENT);
        vm.stopPrank();
    }

    function testShouldNotUpdateLastTotalAssetsMoreThanOnce(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        _setFee();

        uint256 lastTotalAssets = vault.lastTotalAssets();

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        // Try to update lastTotalAssets
        vm.prank(SUPPLIER);
        vault.withdraw(10, SUPPLIER, SUPPLIER);

        assertEq(vault.lastTotalAssets(), lastTotalAssets);
    }

    function testShouldNotIncreaseFeeRecipientBalanceWithingABlock() public {
        uint256 amount = MAX_TEST_AMOUNT;

        _setFee();

        uint256 feeRecipientBalance = vault.balanceOf(FEE_RECIPIENT);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        // Try to update feeRecipientBalance
        vm.prank(SUPPLIER);
        vault.withdraw(10, SUPPLIER, SUPPLIER);

        assertEq(vault.balanceOf(FEE_RECIPIENT), feeRecipientBalance, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testShouldMintSharesToFeeRecipient(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        _setFee();

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(amount, SUPPLIER);

        uint256 lastTotalAssets = vault.lastTotalAssets();

        vm.warp(block.timestamp + 365 days);

        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 interest = totalAssetsAfter - lastTotalAssets;
        uint256 feeAmount = interest.mulDiv(FEE, WAD);
        uint256 feeShares =
            feeAmount.mulDiv(vault.totalSupply() + 1, totalAssetsAfter - feeAmount + 1, Math.Rounding.Down);

        vm.prank(SUPPLIER);
        vault.redeem(shares / 10000, SUPPLIER, SUPPLIER);

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0, "fee recipient balance is zero");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
        assertApproxEqAbs(
            vault.convertToAssets(vault.balanceOf(FEE_RECIPIENT)),
            amount.mulDiv(FEE, WAD),
            1,
            "fee recipient balance approx"
        );
    }

    function testDepositShouldAccrueFee() public {
        _setFee();

        // Deposit to generate fees.
        vm.prank(SUPPLIER);
        vault.deposit(MAX_TEST_AMOUNT, SUPPLIER);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        vm.warp(block.timestamp + 1);

        vm.prank(SUPPLIER);
        vault.deposit(MAX_TEST_AMOUNT, SUPPLIER);

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }

    function testMintShouldAccrueFee() public {
        _setFee();

        // Deposit to generate fees.
        vm.prank(SUPPLIER);
        vault.deposit(MAX_TEST_AMOUNT, SUPPLIER);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        vm.warp(block.timestamp + 1);

        vm.prank(SUPPLIER);
        vault.mint(MAX_TEST_AMOUNT, SUPPLIER);

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }

    function testRedeemShouldAccrueFee() public {
        _setFee();

        // Deposit to generate fees.
        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(MAX_TEST_AMOUNT, SUPPLIER);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        vm.warp(block.timestamp + 1);

        vm.prank(SUPPLIER);
        vault.redeem(shares / 10, SUPPLIER, SUPPLIER);

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }

    function testWithdrawShouldAccrueFee() public {
        _setFee();

        // Deposit to generate fees.
        vm.prank(SUPPLIER);
        vault.deposit(MAX_TEST_AMOUNT, SUPPLIER);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        vm.warp(block.timestamp + 1);

        vm.prank(SUPPLIER);
        vault.redeem(MAX_TEST_AMOUNT / 10, SUPPLIER, SUPPLIER);

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }

    function testSetFeeShouldAccrueFee() public {
        _setFee();

        // Deposit to generate fees.
        vm.prank(SUPPLIER);
        vault.deposit(MAX_TEST_AMOUNT, SUPPLIER);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        vm.warp(block.timestamp + 1);

        vm.startPrank(OWNER);
        vault.submitPendingFee(0);
        vault.setFee();
        vm.stopPrank();

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }

    function testSetFeeRecipientShouldAccrueFee() public {
        _setFee();

        // Deposit to generate fees.
        vm.prank(SUPPLIER);
        vault.deposit(MAX_TEST_AMOUNT, SUPPLIER);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        vm.warp(block.timestamp + 1);

        vm.prank(OWNER);
        vault.setFeeRecipient(address(0));

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }
}
