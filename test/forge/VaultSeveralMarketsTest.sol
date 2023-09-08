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
    }

    function _setCaps(uint128 cap) internal {
        vm.startPrank(OWNER);
        vault.setCap(allMarkets[0], cap);
        vault.setCap(allMarkets[1], cap);
        vault.setCap(allMarkets[2], cap);
        vm.stopPrank();
    }

    function testMintWithCaps(uint128 cap, uint256 amount) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        amount = bound(amount, MIN_TEST_AMOUNT / 3, 3 * cap);
        uint256 shares = vault.convertToShares(amount);

        _setCaps(cap);

        vm.prank(SUPPLIER);
        vault.mint(shares, SUPPLIER);

        uint256 totalBalanceAfter0 = morpho.expectedSupplyBalance(allMarkets[0], address(vault));
        uint256 totalBalanceAfter1 = morpho.expectedSupplyBalance(allMarkets[1], address(vault));
        uint256 totalBalanceAfter2 = morpho.expectedSupplyBalance(allMarkets[2], address(vault));

        assertEq(vault.balanceOf(SUPPLIER), shares, "balance");
        assertEq(totalBalanceAfter0 + totalBalanceAfter1 + totalBalanceAfter2, amount, "totalBalance");
    }

    function testDepositWithCaps(uint128 cap, uint256 amount) public {
        cap = uint128(bound(cap, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        amount = bound(amount, MIN_TEST_AMOUNT / 3, 3 * cap);

        _setCaps(cap);

        vm.prank(SUPPLIER);
        vault.deposit(amount, SUPPLIER);

        uint256 totalBalanceAfter0 = morpho.expectedSupplyBalance(allMarkets[0], address(vault));
        uint256 totalBalanceAfter1 = morpho.expectedSupplyBalance(allMarkets[1], address(vault));
        uint256 totalBalanceAfter2 = morpho.expectedSupplyBalance(allMarkets[2], address(vault));

        assertEq(vault.balanceOf(SUPPLIER), amount, "balance");
        assertEq(totalBalanceAfter0 + totalBalanceAfter1 + totalBalanceAfter2, amount, "totalBalance");
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

        uint256 totalBalanceAfter0 = morpho.expectedSupplyBalance(allMarkets[0], address(vault));
        uint256 totalBalanceAfter1 = morpho.expectedSupplyBalance(allMarkets[1], address(vault));
        uint256 totalBalanceAfter2 = morpho.expectedSupplyBalance(allMarkets[2], address(vault));

        assertEq(vault.balanceOf(SUPPLIER), shares, "balance");
        assertEq(
            totalBalanceAfter0 + totalBalanceAfter1 + totalBalanceAfter2, alreadyDeposited + amount, "totalBalance"
        );
    }
}
