// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

uint256 constant FEE = 0.2 ether; // 20%

contract FeeTest is BaseTest {
    using Math for uint256;
    using MathLib for uint256;
    using MarketParamsLib for MarketParams;

    address internal FEE_RECIPIENT;

    function setUp() public override {
        super.setUp();

        FEE_RECIPIENT = _addrFromHashedString("FeeRecipient");

        vm.prank(OWNER);
        vault.setFeeRecipient(FEE_RECIPIENT);

        _setFee(FEE);

        for (uint256 i; i < NB_MARKETS; ++i) {
            MarketParams memory marketParams = allMarkets[i];

            // Create some debt on the market to accrue interest.

            borrowableToken.setBalance(SUPPLIER, 1);

            vm.prank(SUPPLIER);
            morpho.supply(marketParams, 1, 0, ONBEHALF, hex"");

            uint256 borrowed = uint256(1).wDivUp(marketParams.lltv);
            collateralToken.setBalance(BORROWER, borrowed);

            vm.startPrank(BORROWER);
            morpho.supplyCollateral(marketParams, borrowed, BORROWER, hex"");
            morpho.borrow(marketParams, 1, 0, BORROWER, BORROWER);
            vm.stopPrank();
        }

        _setCap(allMarkets[0], CAP);
    }

    function _feeShares(uint256 totalAssetsBefore) internal view returns (uint256) {
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 interest = totalAssetsAfter - totalAssetsBefore;
        uint256 feeAmount = interest.wMulDown(FEE);

        return feeAmount.mulDiv(
            vault.totalSupply() + 10 ** DECIMALS_OFFSET, totalAssetsAfter - feeAmount + 1, Math.Rounding.Down
        );
    }

    function testLastTotalAssets(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        borrowableToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
    }

    function testAccrueFeeWithinABlock(uint256 deposited, uint256 withdrawn) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        withdrawn = bound(withdrawn, MIN_TEST_ASSETS, deposited);

        borrowableToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        vm.prank(ONBEHALF);
        vault.withdraw(withdrawn, RECEIVER, ONBEHALF);

        assertEq(vault.balanceOf(FEE_RECIPIENT), 0, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testDepositAccrueFee(uint256 deposited, uint256 assets, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        blocks = _boundBlocks(blocks);

        borrowableToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);

        borrowableToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testMintAccrueFee(uint256 deposited, uint256 assets, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        blocks = _boundBlocks(blocks);

        borrowableToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);

        uint256 shares = vault.convertToShares(assets);

        borrowableToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.mint(shares, ONBEHALF);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testRedeemAccrueFee(uint256 deposited, uint256 withdrawn, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        withdrawn = bound(withdrawn, MIN_TEST_ASSETS, deposited);
        blocks = _boundBlocks(blocks);

        borrowableToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);

        uint256 shares = vault.convertToShares(withdrawn);

        vm.prank(ONBEHALF);
        vault.redeem(shares, RECEIVER, ONBEHALF);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testWithdrawAccrueFee(uint256 deposited, uint256 withdrawn, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        withdrawn = bound(withdrawn, MIN_TEST_ASSETS, deposited);
        blocks = _boundBlocks(blocks);

        borrowableToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);

        vm.prank(ONBEHALF);
        vault.withdraw(withdrawn, RECEIVER, ONBEHALF);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testSetFeeAccrueFee(uint256 deposited, uint256 fee, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        fee = bound(fee, 0, WAD);
        blocks = _boundBlocks(blocks);

        vm.assume(fee != FEE);

        borrowableToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);

        _setFee(fee);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testSetFeeRecipientAccrueFee(uint256 deposited, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        blocks = _boundBlocks(blocks);

        borrowableToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);

        vm.prank(OWNER);
        vault.setFeeRecipient(address(1));

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
        assertEq(vault.balanceOf(address(1)), 0, "vault.balanceOf(address(1))");
    }
}
