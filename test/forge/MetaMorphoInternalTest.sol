// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UtilsLib} from "../../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {SharesMathLib} from "../../lib/morpho-blue/src/libraries/SharesMathLib.sol";

import "./helpers/InternalTest.sol";

contract MetaMorphoInternalTest is InternalTest {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using UtilsLib for uint256;

    /// forge-config: default.allow_internal_expect_revert = true
    function testSetCapMaxQueueLengthExcedeed() public {
        for (uint256 i; i < NB_MARKETS - 1; ++i) {
            _setCap(allMarkets[i], allMarkets[i].id(), CAP);
        }

        vm.expectRevert(ErrorsLib.MaxQueueLengthExceeded.selector);
        _setCap(allMarkets[NB_MARKETS - 1], allMarkets[NB_MARKETS - 1].id(), CAP);
    }

    function testSimulateWithdraw(uint256 suppliedAmount, uint256 borrowedAmount, uint256 assets) public {
        suppliedAmount = bound(suppliedAmount, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        borrowedAmount = bound(borrowedAmount, MIN_TEST_ASSETS, suppliedAmount);

        _setCap(allMarkets[0], allMarkets[0].id(), CAP);
        supplyQueue = [allMarkets[0].id()];

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

        uint256 expectedWithdrawable = MORPHO.expectedSupplyAssets(allMarkets[0], address(this)) - borrowedAmount;
        uint256 expectedRemaining = assets.zeroFloorSub(expectedWithdrawable);

        assertEq(remaining, expectedRemaining, "remaining");
    }
}
