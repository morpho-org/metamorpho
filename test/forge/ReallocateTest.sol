// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {stdError} from "@forge-std/StdError.sol";

import "./helpers/BaseTest.sol";

contract ReallocateTest is BaseTest {
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;

    uint256 internal constant VIRTUAL_SHARES = 1e6;
    uint256 internal constant CAP2 = 1e20;

    // function setUp() public override {
    //     super.setUp();
    // }

    function _setCaps() internal {
        _setCap(allMarkets[0], CAP2);
        _setCap(allMarkets[1], CAP2);
        _setCap(allMarkets[2], CAP2);
    }

    function testReallocateWithdrawOnly(uint256 withdraw0, uint256 withdraw1, uint256 withdraw2) public {
        _setCaps();

        borrowableToken.setBalance(SUPPLIER, 4 * CAP2);

        vm.prank(SUPPLIER);
        vault.deposit(4 * CAP2, SUPPLIER);

        uint256 idleBefore = vault.idle();
        assertEq(vault.idle(), CAP2, "vault.idle() 0");
        assertEq(vault.totalAssets(), 4 * CAP2, "vault.totalAssets() 0");

        uint256 sharesBefore0 = morpho.supplyShares(allMarkets[0].id(), address(vault));
        uint256 sharesBefore1 = morpho.supplyShares(allMarkets[1].id(), address(vault));
        uint256 sharesBefore2 = morpho.supplyShares(allMarkets[2].id(), address(vault));

        withdraw0 = bound(withdraw0, 1, sharesBefore0);
        withdraw1 = bound(withdraw1, 1, sharesBefore1);
        withdraw2 = bound(withdraw2, 1, sharesBefore2);

        MarketAllocation[] memory withdrawn = new MarketAllocation[](3);
        withdrawn[0] = MarketAllocation(allMarkets[0], withdraw0);
        withdrawn[1] = MarketAllocation(allMarkets[1], withdraw1);
        withdrawn[2] = MarketAllocation(allMarkets[2], withdraw2);

        MarketAllocation[] memory supplied;

        assertEq(borrowableToken.balanceOf(address(vault)), CAP2, "borrowableToken.balanceOf(address(vault)");

        vm.prank(ALLOCATOR);
        vault.reallocate(withdrawn, supplied);

        assertEq(
            morpho.supplyShares(allMarkets[0].id(), address(vault)),
            sharesBefore0 - withdraw0,
            "morpho.supplyShares(allMarkets[0].id()"
        );
        assertEq(
            morpho.supplyShares(allMarkets[1].id(), address(vault)),
            sharesBefore1 - withdraw1,
            "morpho.supplyShares(allMarkets[1].id()"
        );
        assertEq(
            morpho.supplyShares(allMarkets[2].id(), address(vault)),
            sharesBefore2 - withdraw2,
            "morpho.supplyShares(allMarkets[2].id()"
        );

        assertGe(vault.idle(), idleBefore, "vault.idle() 1");
        assertApproxEqAbs(vault.totalAssets(), 4 * CAP2, 3, "vault.totalAssets() 1");
    }

    function testReallocateWithdrawAll() public {
        _setCaps();

        borrowableToken.setBalance(SUPPLIER, 4 * CAP2);

        vm.prank(SUPPLIER);
        vault.deposit(4 * CAP2, SUPPLIER);

        assertEq(vault.idle(), CAP2, "vault.idle() 0");
        assertEq(vault.totalAssets(), 4 * CAP2, "vault.totalAssets()");

        uint256 withdraw0 = morpho.supplyShares(allMarkets[0].id(), address(vault));
        uint256 withdraw1 = morpho.supplyShares(allMarkets[1].id(), address(vault));
        uint256 withdraw2 = morpho.supplyShares(allMarkets[2].id(), address(vault));

        MarketAllocation[] memory withdrawn = new MarketAllocation[](3);
        withdrawn[0] = MarketAllocation(allMarkets[0], withdraw0);
        withdrawn[1] = MarketAllocation(allMarkets[1], withdraw1);
        withdrawn[2] = MarketAllocation(allMarkets[2], withdraw2);

        MarketAllocation[] memory supplied;

        assertEq(borrowableToken.balanceOf(address(vault)), CAP2, "borrowableToken.balanceOf(address(vault)");

        vm.prank(ALLOCATOR);
        vault.reallocate(withdrawn, supplied);

        assertEq(morpho.supplyShares(allMarkets[0].id(), address(vault)), 0, "morpho.supplyShares(allMarkets[0].id()");
        assertEq(morpho.supplyShares(allMarkets[1].id(), address(vault)), 0, "morpho.supplyShares(allMarkets[1].id()");
        assertEq(morpho.supplyShares(allMarkets[2].id(), address(vault)), 0, "morpho.supplyShares(allMarkets[2].id()");
        assertEq(vault.idle(), 4 * CAP2, "vault.idle() 1");
    }

    function testReallocateIdle() public {
        borrowableToken.setBalance(SUPPLIER, 4 * CAP2);

        vm.prank(SUPPLIER);
        vault.deposit(4 * CAP2, SUPPLIER);

        assertEq(vault.idle(), 4 * CAP2, "vault.idle() 0");

        _setCaps();

        uint256 supplied0 = CAP2 * VIRTUAL_SHARES;
        uint256 supplied1 = CAP2 * VIRTUAL_SHARES;
        uint256 supplied2 = CAP2 * VIRTUAL_SHARES;

        MarketAllocation[] memory supplied = new MarketAllocation[](3);
        supplied[0] = MarketAllocation(allMarkets[0], supplied0);
        supplied[1] = MarketAllocation(allMarkets[1], supplied1);
        supplied[2] = MarketAllocation(allMarkets[2], supplied2);

        MarketAllocation[] memory withdrawn;

        vm.prank(ALLOCATOR);
        vault.reallocate(withdrawn, supplied);

        assertEq(
            morpho.supplyShares(allMarkets[0].id(), address(vault)), supplied0, "morpho.supplyShares(allMarkets[0].id()"
        );
        assertEq(
            morpho.supplyShares(allMarkets[1].id(), address(vault)), supplied1, "morpho.supplyShares(allMarkets[1].id()"
        );
        assertEq(
            morpho.supplyShares(allMarkets[2].id(), address(vault)), supplied2, "morpho.supplyShares(allMarkets[2].id()"
        );
        assertEq(vault.idle(), CAP2, "vault.idle() 1");
    }

    function testReallocateSupplyCapExceeded(uint256 supplied0) public {
        supplied0 = bound(supplied0, CAP2 * VIRTUAL_SHARES + 1, MAX_TEST_ASSETS);

        _setCap(allMarkets[0], CAP2);

        MarketAllocation[] memory supplied = new MarketAllocation[](1);
        supplied[0] = MarketAllocation(allMarkets[0], supplied0);

        MarketAllocation[] memory withdrawn;

        vm.prank(ALLOCATOR);
        vm.expectRevert(bytes(ErrorsLib.SUPPLY_CAP_EXCEEDED));
        vault.reallocate(withdrawn, supplied);
    }
}
