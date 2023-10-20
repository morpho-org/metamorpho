// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/IntegrationTest.sol";

uint256 constant FEE = 0.2 ether; // 20%

contract FeeTest is IntegrationTest {
    using Math for uint256;
    using MathLib for uint256;
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

        vm.prank(OWNER);
        vault.setFeeRecipient(FEE_RECIPIENT);

        _setFee(FEE);

        for (uint256 i; i < NB_MARKETS; ++i) {
            MarketParams memory marketParams = allMarkets[i];

            // Create some debt on the market to accrue interest.

            loanToken.setBalance(SUPPLIER, MAX_TEST_ASSETS);

            vm.prank(SUPPLIER);
            morpho.supply(marketParams, MAX_TEST_ASSETS, 0, ONBEHALF, hex"");

            uint256 collateral = uint256(MAX_TEST_ASSETS).wDivUp(marketParams.lltv);
            collateralToken.setBalance(BORROWER, collateral);

            vm.startPrank(BORROWER);
            morpho.supplyCollateral(marketParams, collateral, BORROWER, hex"");
            morpho.borrow(marketParams, MAX_TEST_ASSETS, 0, BORROWER, BORROWER);
            vm.stopPrank();
        }

        _setCap(allMarkets[0], CAP);
    }

    function _feeShares(uint256 totalAssetsBefore) internal view returns (uint256) {
        uint256 totalAssetsAfter = vault.totalAssets();
        uint256 interest = totalAssetsAfter - totalAssetsBefore;
        uint256 feeAssets = interest.mulDiv(FEE, WAD);

        return feeAssets.mulDiv(
            vault.totalSupply() + 10 ** ConstantsLib.DECIMALS_OFFSET,
            totalAssetsAfter - feeAssets + 1,
            Math.Rounding.Floor
        );
    }

    function testLastTotalAssets(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
    }

    function testAccrueFeeWithinABlock(uint256 deposited, uint256 withdrawn) public {
        deposited = bound(deposited, MIN_TEST_ASSETS + 1, MAX_TEST_ASSETS);
        // The deposited amount is rounded down on Morpho and thus cannot be withdrawn in a block in most cases.
        withdrawn = bound(withdrawn, MIN_TEST_ASSETS, deposited - 1);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        vm.prank(ONBEHALF);
        vault.withdraw(withdrawn, RECEIVER, ONBEHALF);

        assertApproxEqAbs(vault.balanceOf(FEE_RECIPIENT), 0, 1, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testDepositAccrueFee(uint256 deposited, uint256 newDeposit, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        newDeposit = bound(newDeposit, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        blocks = _boundBlocks(blocks);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);
        vm.assume(feeShares != 0);

        loanToken.setBalance(SUPPLIER, newDeposit);

        vm.prank(SUPPLIER);
        vm.expectEmit();
        emit EventsLib.AccrueFee(feeShares);

        vault.deposit(newDeposit, ONBEHALF);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testMintAccrueFee(uint256 deposited, uint256 newDeposit, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        newDeposit = bound(newDeposit, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        blocks = _boundBlocks(blocks);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);
        vm.assume(feeShares != 0);

        uint256 shares = vault.convertToShares(newDeposit);

        loanToken.setBalance(SUPPLIER, newDeposit);

        vm.prank(SUPPLIER);
        vm.expectEmit();
        emit EventsLib.AccrueFee(feeShares);

        vault.mint(shares, ONBEHALF);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testRedeemAccrueFee(uint256 deposited, uint256 withdrawn, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        withdrawn = bound(withdrawn, MIN_TEST_ASSETS, deposited);
        blocks = _boundBlocks(blocks);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);
        vm.assume(feeShares != 0);

        uint256 shares = vault.convertToShares(withdrawn);

        vm.prank(ONBEHALF);
        vm.expectEmit();
        emit EventsLib.AccrueFee(feeShares);

        vault.redeem(shares, RECEIVER, ONBEHALF);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testWithdrawAccrueFee(uint256 deposited, uint256 withdrawn, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        withdrawn = bound(withdrawn, MIN_TEST_ASSETS, deposited);
        blocks = _boundBlocks(blocks);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);
        vm.assume(feeShares != 0);

        vm.prank(ONBEHALF);
        vm.expectEmit();
        emit EventsLib.AccrueFee(feeShares);

        vault.withdraw(withdrawn, RECEIVER, ONBEHALF);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testSetFeeAccrueFee(uint256 deposited, uint256 fee, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        fee = bound(fee, 0, FEE - 1);
        blocks = _boundBlocks(blocks);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);
        vm.assume(feeShares != 0);

        vm.expectEmit();
        emit EventsLib.AccrueFee(feeShares);
        _setFee(fee);

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
    }

    function testSetFeeRecipientAccrueFee(uint256 deposited, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        blocks = _boundBlocks(blocks);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);
        vm.assume(feeShares != 0);

        vm.expectEmit();
        emit EventsLib.AccrueFee(feeShares);
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets());
        emit EventsLib.SetFeeRecipient(address(1));
        vm.prank(OWNER);
        vault.setFeeRecipient(address(1));

        assertEq(vault.lastTotalAssets(), vault.totalAssets(), "lastTotalAssets");
        assertEq(vault.balanceOf(FEE_RECIPIENT), feeShares, "vault.balanceOf(FEE_RECIPIENT)");
        assertEq(vault.balanceOf(address(1)), 0, "vault.balanceOf(address(1))");
    }

    function testSubmitFeeNotOwner(uint256 fee) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.submitFee(fee);
    }

    function testSubmitFeeMaxFeeExceeded(uint256 fee) public {
        fee = bound(fee, ConstantsLib.MAX_FEE + 1, type(uint256).max);

        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.MaxFeeExceeded.selector);
        vault.submitFee(fee);
    }

    function testSubmitFeeAlreadySet() public {
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.submitFee(FEE);
    }

    function testSetFeeRecipientAlreadySet() public {
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.setFeeRecipient(FEE_RECIPIENT);
    }

    function testSetZeroFeeRecipientWithFee() public {
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.ZeroFeeRecipient.selector);
        vault.setFeeRecipient(address(0));
    }

    function testConvertToAssetsWithFeeAndInterest(uint256 deposited, uint256 assets, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        assets = bound(assets, 1, MAX_TEST_ASSETS);
        blocks = _boundBlocks(blocks);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();
        uint256 sharesBefore = vault.convertToShares(assets);

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);
        uint256 expectedShares = assets.mulDiv(
            vault.totalSupply() + feeShares + 10 ** ConstantsLib.DECIMALS_OFFSET,
            vault.totalAssets() + 1,
            Math.Rounding.Floor
        );
        uint256 shares = vault.convertToShares(assets);

        assertEq(shares, expectedShares, "shares");
        assertLt(shares, sharesBefore, "shares decreased");
    }

    function testConvertToSharesWithFeeAndInterest(uint256 deposited, uint256 shares, uint256 blocks) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        shares = bound(shares, 10 ** ConstantsLib.DECIMALS_OFFSET, MAX_TEST_ASSETS);
        blocks = _boundBlocks(blocks);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();
        uint256 assetsBefore = vault.convertToAssets(shares);

        _forward(blocks);

        uint256 feeShares = _feeShares(totalAssetsBefore);
        uint256 expectedAssets = shares.mulDiv(
            vault.totalAssets() + 1,
            vault.totalSupply() + feeShares + 10 ** ConstantsLib.DECIMALS_OFFSET,
            Math.Rounding.Floor
        );
        uint256 assets = vault.convertToAssets(shares);

        assertEq(assets, expectedAssets, "assets");
        assertGe(assets, assetsBefore, "assets increased");
    }
}
