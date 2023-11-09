// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";

import "./helpers/InternalTest.sol";

contract MetaMorphoInternalTest is InternalTest {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using UtilsLib for uint256;

    function testSetCapMaxQueueLengthExcedeed() public {
        for (uint256 i; i < NB_MARKETS - 1; ++i) {
            Id id = allMarkets[i].id();
            _setCap(id, CAP);
        }

        Id lastId = allMarkets[NB_MARKETS - 1].id();
        vm.expectRevert(ErrorsLib.MaxQueueLengthExceeded.selector);
        _setCap(lastId, CAP);
    }

    function testSuppliableNotEnabledMarket() public {
        Id id = allMarkets[0].id();
        uint256 suppliable = _suppliable(allMarkets[0], id);

        assertEq(suppliable, 0, "suppliable");
    }

    function testSuppliableEnabledMarket(uint256 suppliedAmount) public {
        suppliedAmount = bound(suppliedAmount, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        Id id = allMarkets[0].id();
        _setCap(id, CAP);

        loanToken.setBalance(SUPPLIER, suppliedAmount);
        vm.prank(SUPPLIER);
        this.deposit(suppliedAmount, SUPPLIER);

        uint256 suppliable = _suppliable(allMarkets[0], id);

        assertEq(suppliable, CAP - suppliedAmount, "suppliable");
    }

    function testWithdrawable(uint256 suppliedAmount, uint256 borrowedAmount) public {
        suppliedAmount = bound(suppliedAmount, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        borrowedAmount = bound(borrowedAmount, MIN_TEST_ASSETS, suppliedAmount);

        Id id = allMarkets[0].id();
        _setCap(id, CAP);

        loanToken.setBalance(SUPPLIER, suppliedAmount);
        vm.prank(SUPPLIER);
        this.deposit(suppliedAmount, SUPPLIER);

        uint256 collateral = suppliedAmount.wDivUp(allMarkets[0].lltv);
        collateralToken.setBalance(BORROWER, collateral);

        vm.startPrank(BORROWER);
        morpho.supplyCollateral(allMarkets[0], collateral, BORROWER, hex"");
        morpho.borrow(allMarkets[0], borrowedAmount, 0, BORROWER, BORROWER);
        vm.stopPrank();

        uint256 withdrawable = _withdrawable(allMarkets[0], id);

        uint256 supplyShares = MORPHO.supplyShares(id, address(this));
        (uint256 totalSupplyAssets, uint256 totalSupplyShares,,) = MORPHO.expectedMarketBalances(allMarkets[0]);

        uint256 expectedWithdrawable = supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares) - borrowedAmount;

        assertEq(withdrawable, expectedWithdrawable, "withdrawable");
    }

    function testSimulateWithdraw(uint256 suppliedAmount, uint256 borrowedAmount, uint256 assets) public {
        suppliedAmount = bound(suppliedAmount, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        borrowedAmount = bound(borrowedAmount, MIN_TEST_ASSETS, suppliedAmount);

        Id id = allMarkets[0].id();
        _setCap(id, CAP);

        loanToken.setBalance(SUPPLIER, suppliedAmount);
        vm.prank(SUPPLIER);
        this.deposit(suppliedAmount, SUPPLIER);

        uint256 collateral = suppliedAmount.wDivUp(allMarkets[0].lltv);
        collateralToken.setBalance(BORROWER, collateral);

        vm.startPrank(BORROWER);
        morpho.supplyCollateral(allMarkets[0], collateral, BORROWER, hex"");
        morpho.borrow(allMarkets[0], borrowedAmount, 0, BORROWER, BORROWER);
        vm.stopPrank();

        uint256 remaining = _simulateWithdrawMorpho(assets);

        uint256 supplyShares = MORPHO.supplyShares(id, address(this));
        (uint256 totalSupplyAssets, uint256 totalSupplyShares,,) = MORPHO.expectedMarketBalances(allMarkets[0]);

        uint256 expectedWithdrawable = supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares) - borrowedAmount;
        uint256 expectedRemaining = assets.zeroFloorSub(expectedWithdrawable);

        assertEq(remaining, expectedRemaining, "remaining");
    }
}
