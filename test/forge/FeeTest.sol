// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract FeeTest is BaseTest {
    using Math for uint256;
    using MarketParamsLib for MarketParams;

    uint256 constant internal FEE = 0.1 ether; // 10%

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

    function testLastTotalAssets(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        _setFee();

        assertEq(vault.lastTotalAssets(), 0);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        // Update lastTotalAssets
        vm.prank(SUPPLIER);
        vault.withdraw(10, SUPPLIER, SUPPLIER);

        assertEq(vault.lastTotalAssets(), amount);
    }

    function testAccounting() public {
        uint256 amount = MAX_TEST_AMOUNT;

        _setFee();

        assertEq(vault.lastTotalAssets(), 0);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        // Update lastTotalAssets
        vm.prank(SUPPLIER);
        vault.withdraw(10, SUPPLIER, SUPPLIER);

        // supplier balance 9999999999999999999999999988
        // fee recipient balance 1111111111111111111111111111
        console2.log("supplier balance", vault.balanceOf(SUPPLIER));
        console2.log("fee recipient balance", vault.balanceOf(FEE_RECIPIENT));
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
        uint256 feeShares = feeAmount.mulDiv(vault.totalSupply() + 1, totalAssetsAfter - feeAmount + 1, Math.Rounding.Down);

        vm.prank(SUPPLIER);
        vault.redeem(shares / 10, SUPPLIER, SUPPLIER);

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0, "fee recipient balance is zero");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "fee recipient balance");
    }
}
