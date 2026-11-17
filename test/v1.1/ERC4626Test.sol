// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC20Errors} from "../../lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";
import {IMorphoFlashLoanCallback} from "../../lib/morpho-blue/src/interfaces/IMorphoCallbacks.sol";

import "./helpers/IntegrationTest.sol";

contract ERC4626Test is IntegrationTest, IMorphoFlashLoanCallback {
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
        _sortSupplyQueueIdleLast();
    }

    function testDecimals(uint8 decimals) public {
        vm.mockCall(address(loanToken), abi.encodeWithSignature("decimals()"), abi.encode(decimals));

        vault = createMetaMorpho(OWNER, address(morpho), TIMELOCK, address(loanToken), "MetaMorpho Vault", "MMV");

        assertEq(vault.decimals(), Math.max(18, decimals), "decimals");
    }

    function testMint(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        uint256 shares = vault.convertToShares(assets);

        loanToken.setBalance(SUPPLIER, assets);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets() + assets);
        vm.prank(SUPPLIER);
        uint256 deposited = vault.mint(shares, ONBEHALF);

        assertGt(deposited, 0, "deposited");
        assertEq(loanToken.balanceOf(address(vault)), 0, "balanceOf(vault)");
        assertEq(vault.balanceOf(ONBEHALF), shares, "balanceOf(ONBEHALF)");
        assertEq(morpho.expectedSupplyAssets(allMarkets[0], address(vault)), assets, "expectedSupplyAssets(vault)");
    }

    function testDeposit(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets() + assets);
        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(assets, ONBEHALF);

        assertGt(shares, 0, "shares");
        assertEq(loanToken.balanceOf(address(vault)), 0, "balanceOf(vault)");
        assertEq(vault.balanceOf(ONBEHALF), shares, "balanceOf(ONBEHALF)");
        assertEq(morpho.expectedSupplyAssets(allMarkets[0], address(vault)), assets, "expectedSupplyAssets(vault)");
    }

    function testRedeem(uint256 deposited, uint256 redeemed) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        redeemed = bound(redeemed, 0, shares);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets() - vault.convertToAssets(redeemed));
        vm.prank(ONBEHALF);
        vault.redeem(redeemed, RECEIVER, ONBEHALF);

        assertEq(loanToken.balanceOf(address(vault)), 0, "balanceOf(vault)");
        assertEq(vault.balanceOf(ONBEHALF), shares - redeemed, "balanceOf(ONBEHALF)");
    }

    function testWithdraw(uint256 deposited, uint256 withdrawn) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        withdrawn = bound(withdrawn, 0, deposited);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets() - withdrawn);
        vm.prank(ONBEHALF);
        uint256 redeemed = vault.withdraw(withdrawn, RECEIVER, ONBEHALF);

        assertEq(loanToken.balanceOf(address(vault)), 0, "balanceOf(vault)");
        assertEq(vault.balanceOf(ONBEHALF), shares - redeemed, "balanceOf(ONBEHALF)");
    }

    function testWithdrawIdle(uint256 deposited, uint256 withdrawn) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        withdrawn = bound(withdrawn, 0, deposited);

        _setCap(allMarkets[0], 0);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets() - withdrawn);
        vm.prank(ONBEHALF);
        uint256 redeemed = vault.withdraw(withdrawn, RECEIVER, ONBEHALF);

        assertEq(loanToken.balanceOf(address(vault)), 0, "balanceOf(vault)");
        assertEq(vault.balanceOf(ONBEHALF), shares - redeemed, "balanceOf(ONBEHALF)");
        assertEq(_idle(), deposited - withdrawn, "idle");
    }

    function testRedeemTooMuch(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited * 2);

        vm.startPrank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, SUPPLIER);
        vault.deposit(deposited, ONBEHALF);
        vm.stopPrank();

        vm.prank(SUPPLIER);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, SUPPLIER, shares, shares + 1)
        );
        vault.redeem(shares + 1, RECEIVER, SUPPLIER);
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
        assertEq(morpho.expectedSupplyAssets(allMarkets[0], address(vault)), 0, "expectedSupplyAssets(vault)");
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
        assertEq(morpho.expectedSupplyAssets(allMarkets[0], address(vault)), 0, "expectedSupplyAssets(vault)");
    }

    function testRedeemNotDeposited(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        vm.prank(SUPPLIER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, SUPPLIER, 0, shares));
        vault.redeem(shares, SUPPLIER, SUPPLIER);
    }

    function testRedeemNotApproved(uint256 deposited) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        uint256 shares = vault.deposit(deposited, ONBEHALF);

        vm.prank(RECEIVER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, RECEIVER, 0, shares));
        vault.redeem(shares, RECEIVER, ONBEHALF);
    }

    function testWithdrawNotApproved(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint256 shares = vault.previewWithdraw(assets);
        vm.prank(RECEIVER);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, RECEIVER, 0, shares));
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
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, SUPPLIER, 0, shares));
        vault.transferFrom(ONBEHALF, RECEIVER, shares);
    }

    function testWithdrawMoreThanBalanceButLessThanTotalAssets(uint256 deposited, uint256 assets) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.startPrank(SUPPLIER);
        uint256 shares = vault.deposit(deposited / 2, ONBEHALF);
        vault.deposit(deposited / 2, SUPPLIER);
        vm.stopPrank();

        assets = bound(assets, deposited / 2 + 1, vault.totalAssets());

        uint256 sharesBurnt = vault.previewWithdraw(assets);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, ONBEHALF, shares, sharesBurnt)
        );
        vm.prank(ONBEHALF);
        vault.withdraw(assets, RECEIVER, ONBEHALF);
    }

    function testWithdrawMoreThanTotalAssets(uint256 deposited, uint256 assets) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assets = bound(assets, deposited + 1, type(uint256).max / (deposited + 1));

        vm.prank(ONBEHALF);
        vm.expectRevert(ErrorsLib.NotEnoughLiquidity.selector);
        vault.withdraw(assets, RECEIVER, ONBEHALF);
    }

    function testWithdrawMoreThanBalanceAndLiquidity(uint256 deposited, uint256 assets) public {
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assets = bound(assets, deposited + 1, type(uint256).max / (deposited + 1));

        collateralToken.setBalance(BORROWER, type(uint128).max);

        // Borrow liquidity.
        vm.startPrank(BORROWER);
        morpho.supplyCollateral(allMarkets[0], type(uint128).max, BORROWER, hex"");
        morpho.borrow(allMarkets[0], 1, 0, BORROWER, BORROWER);

        vm.startPrank(ONBEHALF);
        vm.expectRevert(ErrorsLib.NotEnoughLiquidity.selector);
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

    function testMaxWithdraw(uint256 depositedAssets, uint256 borrowedAssets) public {
        depositedAssets = bound(depositedAssets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        borrowedAssets = bound(borrowedAssets, MIN_TEST_ASSETS, depositedAssets);

        loanToken.setBalance(SUPPLIER, depositedAssets);

        vm.prank(SUPPLIER);
        vault.deposit(depositedAssets, ONBEHALF);

        collateralToken.setBalance(BORROWER, type(uint128).max);

        vm.startPrank(BORROWER);
        morpho.supplyCollateral(allMarkets[0], type(uint128).max, BORROWER, hex"");
        morpho.borrow(allMarkets[0], borrowedAssets, 0, BORROWER, BORROWER);

        assertEq(vault.maxWithdraw(ONBEHALF), depositedAssets - borrowedAssets, "maxWithdraw(ONBEHALF)");
    }

    function testMaxWithdrawFlashLoan(uint256 supplied, uint256 deposited) public {
        supplied = bound(supplied, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        deposited = bound(deposited, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, supplied);

        vm.prank(SUPPLIER);
        morpho.supply(allMarkets[0], supplied, 0, ONBEHALF, hex"");

        loanToken.setBalance(SUPPLIER, deposited);

        vm.prank(SUPPLIER);
        vault.deposit(deposited, ONBEHALF);

        assertGt(vault.maxWithdraw(ONBEHALF), 0);

        loanToken.approve(address(morpho), type(uint256).max);
        morpho.flashLoan(address(loanToken), loanToken.balanceOf(address(morpho)), hex"");
    }

    function testMaxDeposit() public {
        _setCap(allMarkets[0], 1 ether);

        Id[] memory supplyQueue = new Id[](1);
        supplyQueue[0] = allMarkets[0].id();

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);

        loanToken.setBalance(SUPPLIER, 1 ether);
        collateralToken.setBalance(BORROWER, 2 ether);

        vm.prank(SUPPLIER);
        morpho.supply(allMarkets[0], 1 ether, 0, SUPPLIER, hex"");

        vm.startPrank(BORROWER);
        morpho.supplyCollateral(allMarkets[0], 2 ether, BORROWER, hex"");
        morpho.borrow(allMarkets[0], 1 ether, 0, BORROWER, BORROWER);
        vm.stopPrank();

        _forward(1_000);

        loanToken.setBalance(SUPPLIER, 1 ether);

        vm.prank(SUPPLIER);
        vault.deposit(1 ether, ONBEHALF);

        assertEq(vault.maxDeposit(SUPPLIER), 0);
    }

    function onMorphoFlashLoan(uint256, bytes memory) external view {
        assertEq(vault.maxWithdraw(ONBEHALF), 0);
    }
}
