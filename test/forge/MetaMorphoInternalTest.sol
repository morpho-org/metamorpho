// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UtilsLib} from "../../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {SharesMathLib} from "../../lib/morpho-blue/src/libraries/SharesMathLib.sol";

import "./helpers/BaseTest.sol";
import {MetaMorphoMock} from "../../src/mocks/MetaMorphoMock.sol";

contract MetaMorphoInternalTest is BaseTest {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using UtilsLib for uint256;

    MetaMorphoMock internal metaMorphoMock;

    function setUp() public virtual override {
        super.setUp();

        metaMorphoMock =
            new MetaMorphoMock(OWNER, address(morpho), 1 days, address(loanToken), "MetaMorpho Vault", "MM");

        vm.startPrank(OWNER);
        metaMorphoMock.setCurator(CURATOR);
        metaMorphoMock.setIsAllocator(ALLOCATOR, true);
        vm.stopPrank();

        vm.startPrank(SUPPLIER);
        loanToken.approve(address(metaMorphoMock), type(uint256).max);
        collateralToken.approve(address(metaMorphoMock), type(uint256).max);
        vm.stopPrank();
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function testSetCapMaxQueueLengthExcedeed() public {
        for (uint256 i; i < NB_MARKETS - 1; ++i) {
            metaMorphoMock.mockSetCap(allMarkets[i], allMarkets[i].id(), CAP);
        }

        vm.expectRevert(ErrorsLib.MaxQueueLengthExceeded.selector);
        metaMorphoMock.mockSetCap(allMarkets[NB_MARKETS - 1], allMarkets[NB_MARKETS - 1].id(), CAP);
    }

    function testSimulateWithdraw(uint256 suppliedAmount, uint256 borrowedAmount, uint256 assets) public {
        suppliedAmount = bound(suppliedAmount, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        borrowedAmount = bound(borrowedAmount, MIN_TEST_ASSETS, suppliedAmount);

        metaMorphoMock.mockSetCap(allMarkets[0], allMarkets[0].id(), CAP);

        Id[] memory ids = new Id[](1);
        ids[0] = allMarkets[0].id();
        metaMorphoMock.mockSetSupplyQueue(ids);

        loanToken.setBalance(SUPPLIER, suppliedAmount);
        vm.prank(SUPPLIER);
        metaMorphoMock.deposit(suppliedAmount, SUPPLIER);

        uint256 collateral = suppliedAmount.wDivUp(allMarkets[0].lltv);
        collateralToken.setBalance(BORROWER, collateral);

        vm.startPrank(BORROWER);
        morpho.supplyCollateral(allMarkets[0], collateral, BORROWER, hex"");
        morpho.borrow(allMarkets[0], borrowedAmount, 0, BORROWER, BORROWER);
        vm.stopPrank();

        uint256 remaining = metaMorphoMock.mockSimulateWithdrawMorpho(assets);

        uint256 expectedWithdrawable =
            morpho.expectedSupplyAssets(allMarkets[0], address(metaMorphoMock)) - borrowedAmount;
        uint256 expectedRemaining = assets.zeroFloorSub(expectedWithdrawable);

        assertEq(remaining, expectedRemaining, "remaining");
    }
}
