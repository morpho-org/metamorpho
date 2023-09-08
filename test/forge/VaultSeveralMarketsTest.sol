// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

import "./BaseTest.sol";

contract VaultSeveralMarketsTest is BaseTest {
    using MorphoBalancesLib for Morpho;
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

        _submitAndEnableMarket(allMarkets[0], CAP);
        _submitAndEnableMarket(allMarkets[1], CAP);
        _submitAndEnableMarket(allMarkets[2], CAP);

        Id[] memory withdrawAllocationOrder = new Id[](3);
        withdrawAllocationOrder[0] = allMarkets[2].id();
        withdrawAllocationOrder[1] = allMarkets[1].id();
        withdrawAllocationOrder[2] = allMarkets[0].id();

        vm.prank(ALLOCATOR);
        vault.setWithdrawAllocationOrder(withdrawAllocationOrder);
    }

    function _setCaps(uint128 cap) internal {
        vm.startPrank(OWNER);
        vault.setCap(allMarkets[0], cap);
        vault.setCap(allMarkets[1], cap);
        vault.setCap(allMarkets[2], cap);
        vm.stopPrank();
    }

    function _assertBalances(uint128 cap, uint256 amount) internal {
        uint256 totalBalanceAfter0 = morpho.expectedSupplyBalance(allMarkets[0], address(vault));
        uint256 totalBalanceAfter1 = morpho.expectedSupplyBalance(allMarkets[1], address(vault));
        uint256 totalBalanceAfter2 = morpho.expectedSupplyBalance(allMarkets[2], address(vault));

        assertEq(totalBalanceAfter0 + totalBalanceAfter1 + totalBalanceAfter2, amount, "totalBalance");

        if (amount >= 3 * cap) {
            assertEq(totalBalanceAfter0, cap, "totalBalance0");
            assertEq(totalBalanceAfter1, cap, "totalBalance1");
            assertEq(totalBalanceAfter2, cap, "totalBalance2");
        } else if (amount >= 2 * cap) {
            assertEq(totalBalanceAfter0, cap, "totalBalance0");
            assertEq(totalBalanceAfter1, cap, "totalBalance1");
            assertEq(totalBalanceAfter2, amount % (2 * cap), "totalBalance2");
        } else if (amount >= cap) {
            assertEq(totalBalanceAfter0, cap, "totalBalance0");
            assertEq(totalBalanceAfter1, amount % cap, "totalBalance1");
            assertEq(totalBalanceAfter2, 0, "totalBalance2");
        } else {
            assertEq(totalBalanceAfter0, amount, "totalBalance0");
            assertEq(totalBalanceAfter1, 0, "totalBalance1");
            assertEq(totalBalanceAfter2, 0, "totalBalance2");
        }
    }

    /* MINT/DEPOSIT */

    function testMintWithCaps(uint128 cap, uint256 amount) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        amount = bound(amount, MIN_TEST_AMOUNT / 3, 3 * cap);
        uint256 shares = vault.convertToShares(amount);

        _setCaps(cap);

        vm.prank(SUPPLIER);
        vault.mint(shares, SUPPLIER);

        assertEq(vault.balanceOf(SUPPLIER), shares, "balance");
        _assertBalances(cap, amount);
    }

    function testDepositWithCaps(uint128 cap, uint256 amount) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        amount = bound(amount, MIN_TEST_AMOUNT / 3, 3 * cap);

        _setCaps(cap);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        assertEq(vault.balanceOf(SUPPLIER), amount, "balance");
        _assertBalances(cap, amount);
    }

    function testShouldNotMintMoreThanCaps(uint128 cap, uint256 amount) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT / 3));
        amount = bound(amount, 3 * cap + 1, MAX_TEST_AMOUNT);
        uint256 shares = vault.convertToShares(amount);

        _setCaps(cap);

        vm.prank(SUPPLIER);
        vm.expectRevert(bytes(ErrorsLib.DEPOSIT_ORDER_FAILED));
        vault.mint(shares, SUPPLIER);
    }

    function testShouldNotDepositMoreThanCaps(uint128 cap, uint256 amount) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT / 3));
        amount = bound(amount, 3 * cap + 1, MAX_TEST_AMOUNT);

        _setCaps(cap);

        vm.prank(SUPPLIER);
        vm.expectRevert(bytes(ErrorsLib.DEPOSIT_ORDER_FAILED));
        vault.deposit(amount, SUPPLIER);
    }

    function testMintWithCapsWithSeveralUsers(uint128 cap, uint256 alreadyDeposited, uint256 amount) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        alreadyDeposited = bound(alreadyDeposited, 3 * cap / 2, 3 * cap);
        amount = bound(amount, 0, 3 * cap - alreadyDeposited);

        _setCaps(cap);

        vm.prank(RECEIVER);
        vault.deposit(alreadyDeposited, RECEIVER);

        uint256 shares = vault.convertToShares(amount);

        vm.prank(SUPPLIER);
        vault.mint(shares, SUPPLIER);

        assertEq(vault.balanceOf(SUPPLIER), shares, "balance");
        _assertBalances(cap, alreadyDeposited + amount);
    }

    function testShouldNotMintMoreThanCapsWithSeveralUsers(uint128 cap, uint256 alreadyDeposited, uint256 amount)
        public
    {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT / 3));
        alreadyDeposited = bound(alreadyDeposited, 3 * cap / 2, 3 * cap);
        amount = bound(amount, 3 * cap - alreadyDeposited + 1, MAX_TEST_AMOUNT);

        _setCaps(cap);

        vm.prank(RECEIVER);
        vault.deposit(alreadyDeposited, RECEIVER);

        uint256 shares = vault.convertToShares(amount);

        vm.prank(SUPPLIER);
        vm.expectRevert(bytes(ErrorsLib.DEPOSIT_ORDER_FAILED));
        vault.mint(shares, SUPPLIER);
    }

    function testMintShouldSkipMarketWhenCallFail(uint256 amount) public {
        amount = bound(amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT);
        uint256 shares = vault.convertToShares(amount);

        vm.prank(SUPPLIER);
        vm.mockCallRevert(
            address(morpho), 0, abi.encodeCall(morpho.supply, (allMarkets[0], amount, 0, address(vault), hex"")), hex""
        );
        vault.mint(shares, SUPPLIER);

        assertEq(vault.balanceOf(SUPPLIER), shares, "balance");

        uint256 totalBalanceAfter0 = morpho.expectedSupplyBalance(allMarkets[0], address(vault));
        uint256 totalBalanceAfter1 = morpho.expectedSupplyBalance(allMarkets[1], address(vault));
        uint256 totalBalanceAfter2 = morpho.expectedSupplyBalance(allMarkets[2], address(vault));

        assertEq(totalBalanceAfter0, 0, "totalBalance0");
        assertEq(totalBalanceAfter1, amount, "totalBalance1");
        assertEq(totalBalanceAfter2, 0, "totalBalance2");
    }

    /* REDEEM/WITHDRAW */

    function testRedeemSeveralMarkets(uint128 cap, uint256 amount, uint256 toRedeem) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        amount = bound(amount, MIN_TEST_AMOUNT / 3, 3 * cap);

        _setCaps(cap);

        vm.startPrank(SUPPLIER);
        uint256 shares = vault.deposit(amount, SUPPLIER);
        toRedeem = bound(toRedeem, 0, shares);
        uint256 withdrawn = vault.redeem(toRedeem, SUPPLIER, SUPPLIER);
        vm.stopPrank();

        _assertBalances(cap, amount - withdrawn);
    }

    function testWithdrawSeveralMarkets(uint128 cap, uint256 amount, uint256 toWithdraw) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        amount = bound(amount, MIN_TEST_AMOUNT / 3, 3 * cap);

        _setCaps(cap);

        vm.startPrank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);
        toWithdraw = bound(toWithdraw, 0, amount);
        vault.withdraw(toWithdraw, SUPPLIER, SUPPLIER);
        vm.stopPrank();

        _assertBalances(cap, amount - toWithdraw);
    }

    function _borrow(MarketParams memory marketParams, uint256 amount) internal {
        deal(address(collateralToken), BORROWER, type(uint256).max);

        vm.startPrank(BORROWER);
        collateralToken.approve(address(morpho), type(uint256).max);
        morpho.supplyCollateral(marketParams, type(uint128).max, BORROWER, hex"");
        morpho.borrow(marketParams, amount, 0, BORROWER, BORROWER);
        vm.stopPrank();
    }

    function testWithdrawSeveralMarketsWithLessLiquidity(uint128 cap, uint256 toWithdraw, uint256 borrowed) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        uint256 amount = 3 * cap;
        borrowed = bound(borrowed, 1, cap);

        _setCaps(cap);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        _borrow(allMarkets[1], borrowed);

        toWithdraw = bound(toWithdraw, 0, amount - borrowed);

        vm.prank(SUPPLIER);
        vault.withdraw(toWithdraw, SUPPLIER, SUPPLIER);

        uint256 totalBalanceAfter0 = morpho.expectedSupplyBalance(allMarkets[0], address(vault));
        uint256 totalBalanceAfter1 = morpho.expectedSupplyBalance(allMarkets[1], address(vault));
        uint256 totalBalanceAfter2 = morpho.expectedSupplyBalance(allMarkets[2], address(vault));

        assertEq(totalBalanceAfter0 + totalBalanceAfter1 + totalBalanceAfter2, amount - toWithdraw, "totalBalance");

        if (toWithdraw >= 3 * cap) {
            assertEq(totalBalanceAfter0, 0, "totalBalance0");
            assertEq(totalBalanceAfter1, 0, "totalBalance1");
            assertEq(totalBalanceAfter2, 0, "totalBalance2");
        } else if (toWithdraw >= 2 * cap) {
            assertEq(totalBalanceAfter0, 3 * cap - toWithdraw - borrowed, "totalBalance0");
            assertEq(totalBalanceAfter1, borrowed, "totalBalance1");
            assertEq(totalBalanceAfter2, 0, "totalBalance2");
        } else if (toWithdraw >= cap) {
            uint256 bal0;
            uint256 bal1;
            if (toWithdraw - cap > cap - borrowed) {
                bal0 = 3 * cap - borrowed - toWithdraw;
                bal1 = borrowed;
            } else {
                bal0 = cap;
                bal1 = 2 * cap - toWithdraw;
            }
            assertEq(totalBalanceAfter0, bal0, "totalBalance0");
            assertEq(totalBalanceAfter1, bal1, "totalBalance1");
            assertEq(totalBalanceAfter2, 0, "totalBalance2");
        } else {
            assertEq(totalBalanceAfter0, cap, "totalBalance0");
            assertEq(totalBalanceAfter1, cap, "totalBalance1");
            assertEq(totalBalanceAfter2, cap - toWithdraw, "totalBalance2");
        }
    }

    function testWithdrawShouldSkipMarketWhenCallFail(uint128 cap, uint256 toWithdraw) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        uint256 amount = 3 * cap;

        _setCaps(cap);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        toWithdraw = bound(toWithdraw, 0, 2 * cap);

        vm.prank(SUPPLIER);
        if (toWithdraw > cap) {
            vm.mockCallRevert(
                address(morpho),
                0,
                abi.encodeCall(morpho.withdraw, (allMarkets[1], toWithdraw - cap, 0, address(vault), address(vault))),
                hex""
            );
        }
        vault.withdraw(toWithdraw, SUPPLIER, SUPPLIER);

        uint256 totalBalanceAfter0 = morpho.expectedSupplyBalance(allMarkets[0], address(vault));
        uint256 totalBalanceAfter1 = morpho.expectedSupplyBalance(allMarkets[1], address(vault));
        uint256 totalBalanceAfter2 = morpho.expectedSupplyBalance(allMarkets[2], address(vault));

        assertEq(totalBalanceAfter0 + totalBalanceAfter1 + totalBalanceAfter2, amount - toWithdraw, "totalBalance");

        if (toWithdraw == 2 * cap) {
            assertEq(totalBalanceAfter0, 0, "totalBalance0");
            assertEq(totalBalanceAfter1, cap, "totalBalance1");
            assertEq(totalBalanceAfter2, 0, "totalBalance2");
        } else if (toWithdraw >= cap) {
            assertEq(totalBalanceAfter0, 2 * cap - toWithdraw, "totalBalance0");
            assertEq(totalBalanceAfter1, cap, "totalBalance1");
            assertEq(totalBalanceAfter2, 0, "totalBalance2");
        } else {
            assertEq(totalBalanceAfter0, cap, "totalBalance0");
            assertEq(totalBalanceAfter1, cap, "totalBalance1");
            assertEq(totalBalanceAfter2, cap - toWithdraw, "totalBalance2");
        }
    }

    function testWithdrawShouldRevertWhenNotEnoughLiquidity(uint128 cap, uint256 toWithdraw, uint256 borrowed) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        uint256 amount = 3 * cap;
        borrowed = bound(borrowed, 1, cap);

        _setCaps(cap);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        _borrow(allMarkets[1], borrowed);

        toWithdraw = bound(toWithdraw, amount - borrowed + 1, amount);

        vm.prank(SUPPLIER);
        vm.expectRevert(bytes(ErrorsLib.WITHDRAW_ORDER_FAILED));
        vault.withdraw(toWithdraw, SUPPLIER, SUPPLIER);
    }

    function testWithdrawShouldRevertWhenSkipMarketNotEnoughLiquidity(uint128 cap, uint256 toWithdraw) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        uint256 amount = 3 * cap;

        _setCaps(cap);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        toWithdraw = bound(toWithdraw, 2 * cap + 1, amount);

        vm.prank(SUPPLIER);
        vm.mockCallRevert(
            address(morpho),
            0,
            abi.encodeCall(morpho.withdraw, (allMarkets[1], cap, 0, address(vault), address(vault))),
            hex""
        );
        vm.expectRevert(bytes(ErrorsLib.WITHDRAW_ORDER_FAILED));
        vault.withdraw(toWithdraw, SUPPLIER, SUPPLIER);
    }
}
