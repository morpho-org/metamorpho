// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract FeeTest is BaseTest {
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

    function testShouldMintSharesToFeeRecipient(uint256 amount) public {
        _setFee();

        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(amount, SUPPLIER);

        _borrow(allMarkets[0], amount / 2);

        vm.warp(block.timestamp + 365 days);

        vm.prank(SUPPLIER);
        vault.redeem(shares / 3, SUPPLIER, SUPPLIER);

        assertGt(vault.balanceOf(FEE_RECIPIENT), 0, "fee recipient balance is zero");
    }
}
