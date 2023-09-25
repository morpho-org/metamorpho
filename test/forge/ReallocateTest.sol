// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";

import "./helpers/BaseTest.sol";

contract ReallocateTest is BaseTest {
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;
    using SharesMathLib for uint256;
    using MorphoLib for IMorpho;

    uint256 internal constant VIRTUAL_SHARES = 1e6;
    uint256 internal constant CAP2 = 1e20;

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
        assertEq(idleBefore, CAP2, "vault.idle() 0");
        assertEq(vault.totalAssets(), 4 * CAP2, "vault.totalAssets() 0");

        uint256 sharesBefore0 = morpho.supplyShares(allMarkets[0].id(), address(vault));
        uint256 sharesBefore1 = morpho.supplyShares(allMarkets[1].id(), address(vault));
        uint256 sharesBefore2 = morpho.supplyShares(allMarkets[2].id(), address(vault));

        withdraw0 = bound(withdraw0, 1, sharesBefore0);
        withdraw1 = bound(withdraw1, 1, sharesBefore1);
        withdraw2 = bound(withdraw2, 1, sharesBefore2);

        MarketAllocation[] memory withdrawn = new MarketAllocation[](3);
        withdrawn[0] = MarketAllocation(allMarkets[0], 0, withdraw0);
        withdrawn[1] = MarketAllocation(allMarkets[1], 0, withdraw1);
        withdrawn[2] = MarketAllocation(allMarkets[2], 0, withdraw2);

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
        withdrawn[0] = MarketAllocation(allMarkets[0], 0, withdraw0);
        withdrawn[1] = MarketAllocation(allMarkets[1], 0, withdraw1);
        withdrawn[2] = MarketAllocation(allMarkets[2], 0, withdraw2);

        MarketAllocation[] memory supplied;

        assertEq(borrowableToken.balanceOf(address(vault)), CAP2, "borrowableToken.balanceOf(address(vault)");

        vm.prank(ALLOCATOR);
        vault.reallocate(withdrawn, supplied);

        assertEq(morpho.supplyShares(allMarkets[0].id(), address(vault)), 0, "morpho.supplyShares(allMarkets[0].id()");
        assertEq(morpho.supplyShares(allMarkets[1].id(), address(vault)), 0, "morpho.supplyShares(allMarkets[1].id()");
        assertEq(morpho.supplyShares(allMarkets[2].id(), address(vault)), 0, "morpho.supplyShares(allMarkets[2].id()");
        assertEq(vault.idle(), 4 * CAP2, "vault.idle() 1");
    }

    function testReallocateSupplyIdle(uint256 supplied0, uint256 supplied1, uint256 supplied2) public {
        borrowableToken.setBalance(SUPPLIER, 4 * CAP2);
        vm.prank(SUPPLIER);
        vault.deposit(4 * CAP2, SUPPLIER);

        assertEq(vault.idle(), 4 * CAP2, "vault.idle() 0");

        _setCaps();

        supplied0 = bound(supplied0, VIRTUAL_SHARES, CAP2 * VIRTUAL_SHARES);
        supplied1 = bound(supplied1, VIRTUAL_SHARES, CAP2 * VIRTUAL_SHARES);
        supplied2 = bound(supplied2, VIRTUAL_SHARES, CAP2 * VIRTUAL_SHARES);

        MarketAllocation[] memory supplied = new MarketAllocation[](3);
        supplied[0] = MarketAllocation(allMarkets[0], 0, supplied0);
        supplied[1] = MarketAllocation(allMarkets[1], 0, supplied1);
        supplied[2] = MarketAllocation(allMarkets[2], 0, supplied2);

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

        uint256 expectedIdle =
            4 * CAP2 - supplied0 / VIRTUAL_SHARES - supplied1 / VIRTUAL_SHARES - supplied2 / VIRTUAL_SHARES;
        assertApproxEqAbs(vault.idle(), expectedIdle, 3, "vault.idle() 1");
    }

    function testReallocateWithdrawSupply(Vars memory withdraw, Vars memory supply) public {
        _setCaps();

        borrowableToken.setBalance(SUPPLIER, 4 * CAP2);
        vm.prank(SUPPLIER);
        vault.deposit(4 * CAP2, SUPPLIER);

        assertEq(vault.idle(), CAP2, "vault.idle() 0");
        assertEq(vault.totalAssets(), 4 * CAP2, "vault.totalAssets()");

        Vars memory sharesBefore;

        sharesBefore.val0 = morpho.supplyShares(allMarkets[0].id(), address(vault));
        sharesBefore.val1 = morpho.supplyShares(allMarkets[1].id(), address(vault));
        sharesBefore.val2 = morpho.supplyShares(allMarkets[2].id(), address(vault));

        withdraw.val0 = bound(withdraw.val0, VIRTUAL_SHARES, sharesBefore.val0);
        withdraw.val1 = bound(withdraw.val1, VIRTUAL_SHARES, sharesBefore.val1);
        withdraw.val2 = bound(withdraw.val2, VIRTUAL_SHARES, sharesBefore.val2);

        MarketAllocation[] memory withdrawn = new MarketAllocation[](3);
        withdrawn[0] = MarketAllocation(allMarkets[0], 0, withdraw.val0);
        withdrawn[1] = MarketAllocation(allMarkets[1], 0, withdraw.val1);
        withdrawn[2] = MarketAllocation(allMarkets[2], 0, withdraw.val2);

        uint256 expectedIdle;
        (supply, expectedIdle) = _boundSupply(withdraw, supply);

        MarketAllocation[] memory supplied = new MarketAllocation[](3);
        supplied[0] = MarketAllocation(allMarkets[0], 0, supply.val0);
        supplied[1] = MarketAllocation(allMarkets[1], 0, supply.val1);
        supplied[2] = MarketAllocation(allMarkets[2], 0, supply.val2);

        vm.prank(ALLOCATOR);
        vault.reallocate(withdrawn, supplied);

        assertEq(
            morpho.supplyShares(allMarkets[0].id(), address(vault)),
            sharesBefore.val0 - withdraw.val0 + supply.val0,
            "morpho.supplyShares(allMarkets[0].id()"
        );
        assertEq(
            morpho.supplyShares(allMarkets[1].id(), address(vault)),
            sharesBefore.val1 - withdraw.val1 + supply.val1,
            "morpho.supplyShares(allMarkets[1].id()"
        );
        assertEq(
            morpho.supplyShares(allMarkets[2].id(), address(vault)),
            sharesBefore.val2 - withdraw.val2 + supply.val2,
            "morpho.supplyShares(allMarkets[2].id()"
        );
        assertEq(vault.idle(), expectedIdle, "vault.idle() 1");
    }

    /// @dev Needed to avoid stack too deep errors.
    struct Vars {
        uint256 val0;
        uint256 val1;
        uint256 val2;
    }

    /// @dev Needed to avoid stack too deep errors.
    function _boundSupply(Vars memory withdraw, Vars memory supply)
        internal
        view
        returns (Vars memory, uint256 availableForSupply)
    {
        Vars memory totalSupplyAssets;
        Vars memory totalSupplyShares;
        (totalSupplyAssets.val0, totalSupplyShares.val0,,) = morpho.expectedMarketBalances(allMarkets[0]);
        (totalSupplyAssets.val1, totalSupplyShares.val1,,) = morpho.expectedMarketBalances(allMarkets[1]);
        (totalSupplyAssets.val2, totalSupplyShares.val2,,) = morpho.expectedMarketBalances(allMarkets[2]);

        Vars memory withdrawAssets;
        withdrawAssets.val0 = withdraw.val0.toAssetsDown(totalSupplyAssets.val0, totalSupplyShares.val0);
        withdrawAssets.val1 = withdraw.val1.toAssetsDown(totalSupplyAssets.val1, totalSupplyShares.val1);
        withdrawAssets.val2 = withdraw.val2.toAssetsDown(totalSupplyAssets.val2, totalSupplyShares.val2);

        availableForSupply = withdrawAssets.val0 + withdrawAssets.val1 + withdrawAssets.val2 + vault.idle();

        Vars memory supplyAssetsAfter;
        supplyAssetsAfter.val0 = totalSupplyAssets.val0 - withdrawAssets.val0;
        supplyAssetsAfter.val1 = totalSupplyAssets.val1 - withdrawAssets.val1;
        supplyAssetsAfter.val2 = totalSupplyAssets.val2 - withdrawAssets.val2;

        Vars memory sharesAfter;
        sharesAfter.val0 = totalSupplyShares.val0 - withdraw.val0;
        sharesAfter.val1 = totalSupplyShares.val1 - withdraw.val1;
        sharesAfter.val2 = totalSupplyShares.val2 - withdraw.val2;

        supply.val0 = bound(
            supply.val0,
            1,
            UtilsLib.min(availableForSupply, CAP2 - supplyAssetsAfter.val0).toSharesDown(
                supplyAssetsAfter.val0, sharesAfter.val0
            )
        );
        availableForSupply -= supply.val0.toAssetsUp(supplyAssetsAfter.val0, sharesAfter.val0);

        supply.val1 = bound(
            supply.val1,
            1,
            UtilsLib.min(availableForSupply, CAP2 - supplyAssetsAfter.val1).toSharesDown(
                supplyAssetsAfter.val1, sharesAfter.val1
            )
        );
        availableForSupply -= supply.val1.toAssetsUp(supplyAssetsAfter.val1, sharesAfter.val1);

        supply.val2 = bound(
            supply.val2,
            1,
            UtilsLib.min(availableForSupply, CAP2 - supplyAssetsAfter.val2).toSharesDown(
                supplyAssetsAfter.val2, sharesAfter.val2
            )
        );
        availableForSupply -= supply.val2.toAssetsUp(supplyAssetsAfter.val2, sharesAfter.val2);

        return (supply, availableForSupply);
    }
}
