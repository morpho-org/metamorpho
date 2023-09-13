// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

contract FeeTest is BaseTest {
    using Math for uint256;
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

        _submitAndEnableMarket(allMarkets[0], CAP);
    }

    function testShouldNotUpdateLastTotalAssetsMoreThanOnce(uint256 amount) public {
        amount = bound(amount, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        uint256 lastTotalAssets = vault.lastTotalAssets();

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        // Try to update lastTotalAssets
        vm.prank(SUPPLIER);
        vault.withdraw(10, SUPPLIER, SUPPLIER);

        assertEq(vault.lastTotalAssets(), lastTotalAssets);
    }

    function testShouldNotIncreaseFeeRecipientBalanceWithingABlock() public {
        uint256 amount = MAX_TEST_ASSETS;

        uint256 feeRecipientBalance = vault.balanceOf(FEE_RECIPIENT);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        // Try to update feeRecipientBalance
        vm.prank(SUPPLIER);
        vault.withdraw(10, SUPPLIER, SUPPLIER);

        assertEq(vault.balanceOf(FEE_RECIPIENT), feeRecipientBalance, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testShouldMintSharesToFeeRecipient(uint256 amount) public {
        amount = bound(amount, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

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

    function testDepositAccrueFee(uint256 assets, uint256 deposited, uint256 blocks) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        blocks = _boundBlocks(blocks);

        borrowableToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        _forward(blocks);

        borrowableToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }

    function testMintAccrueFee(uint256 assets, uint256 deposited, uint256 blocks) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        blocks = _boundBlocks(blocks);

        borrowableToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        _forward(blocks);

        uint256 shares = vault.convertToShares(assets);

        borrowableToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.mint(shares, ONBEHALF);

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }

    function testRedeemAccrueFee(uint256 shares, uint256 deposited, uint256 blocks) public {
        // deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        // blocks = _boundBlocks(blocks);

        // borrowableToken.setBalance(SUPPLIER, deposited);

        // vm.prank(SUPPLIER);
        // uint256 minted = vault.deposit(deposited, ONBEHALF);

        // assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        // _forward(blocks);

        // shares = bound(shares, 1, minted);

        // borrowableToken.setBalance(ONBEHALF, vault.convertToAssets(shares));

        // vm.prank(ONBEHALF);
        // vault.redeem(shares, RECEIVER, ONBEHALF);

        // assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }

    function testWithdrawShouldAccrueFee() public {
        // Deposit to generate fees.
        vm.prank(SUPPLIER);
        vault.deposit(MAX_TEST_ASSETS, SUPPLIER);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        vm.warp(block.timestamp + 1);

        vm.prank(SUPPLIER);
        vault.redeem(MAX_TEST_ASSETS / 10, SUPPLIER, SUPPLIER);

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }

    function testSetFeeShouldAccrueFee() public {
        // Deposit to generate fees.
        vm.prank(SUPPLIER);
        vault.deposit(MAX_TEST_ASSETS, SUPPLIER);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        vm.warp(block.timestamp + 1);

        vm.startPrank(OWNER);
        vault.submitPendingFee(0);
        vault.setFee();
        vm.stopPrank();

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }

    function testSetFeeRecipientShouldAccrueFee() public {
        // Deposit to generate fees.
        vm.prank(SUPPLIER);
        vault.deposit(MAX_TEST_ASSETS, SUPPLIER);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0);

        vm.warp(block.timestamp + 1);

        vm.prank(OWNER);
        vault.setFeeRecipient(address(0));

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0);
    }
}
