// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";

import "./helpers/BaseTest.sol";

uint256 constant CAP2 = 100e18;
uint256 constant INITIAL_DEPOSIT = 4 * CAP2;

contract ReallocateWithdrawTest is BaseTest {
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;
    using SharesMathLib for uint256;
    using MorphoLib for IMorpho;

    MarketAllocation[] internal withdrawn;
    MarketAllocation[] internal supplied;

    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP2);
        _setCap(allMarkets[1], CAP2);
        _setCap(allMarkets[2], CAP2);

        borrowableToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);

        vm.prank(SUPPLIER);
        vault.deposit(INITIAL_DEPOSIT, ONBEHALF);
    }

    function testReallocateWithdrawOnly(uint256[3] memory withdrawnShares) public {
        uint256[3] memory sharesBefore = [
            morpho.supplyShares(allMarkets[0].id(), address(vault)),
            morpho.supplyShares(allMarkets[1].id(), address(vault)),
            morpho.supplyShares(allMarkets[2].id(), address(vault))
        ];

        withdrawnShares[0] = bound(withdrawnShares[0], 1, sharesBefore[0]);
        withdrawnShares[1] = bound(withdrawnShares[1], 1, sharesBefore[1]);
        withdrawnShares[2] = bound(withdrawnShares[2], 1, sharesBefore[2]);

        withdrawn.push(MarketAllocation(allMarkets[0], 0, withdrawnShares[0]));
        withdrawn.push(MarketAllocation(allMarkets[1], 0, withdrawnShares[1]));
        withdrawn.push(MarketAllocation(allMarkets[2], 0, withdrawnShares[2]));

        uint256 idleBefore = vault.idle();

        vm.prank(ALLOCATOR);
        vault.reallocate(withdrawn, supplied);

        assertEq(
            morpho.supplyShares(allMarkets[0].id(), address(vault)),
            sharesBefore[0] - withdrawnShares[0],
            "morpho.supplyShares(0)"
        );
        assertEq(
            morpho.supplyShares(allMarkets[1].id(), address(vault)),
            sharesBefore[1] - withdrawnShares[1],
            "morpho.supplyShares(1)"
        );
        assertEq(
            morpho.supplyShares(allMarkets[2].id(), address(vault)),
            sharesBefore[2] - withdrawnShares[2],
            "morpho.supplyShares(2)"
        );

        assertGe(vault.idle(), idleBefore, "vault.idle() 1");
        assertApproxEqAbs(vault.totalAssets(), INITIAL_DEPOSIT, 3, "vault.totalAssets() 1");
    }

    function testReallocateWithdrawAll() public {
        withdrawn.push(MarketAllocation(allMarkets[0], 0, morpho.supplyShares(allMarkets[0].id(), address(vault))));
        withdrawn.push(MarketAllocation(allMarkets[1], 0, morpho.supplyShares(allMarkets[1].id(), address(vault))));
        withdrawn.push(MarketAllocation(allMarkets[2], 0, morpho.supplyShares(allMarkets[2].id(), address(vault))));

        vm.prank(ALLOCATOR);
        vault.reallocate(withdrawn, supplied);

        assertEq(morpho.supplyShares(allMarkets[0].id(), address(vault)), 0, "morpho.supplyShares(0)");
        assertEq(morpho.supplyShares(allMarkets[1].id(), address(vault)), 0, "morpho.supplyShares(1)");
        assertEq(morpho.supplyShares(allMarkets[2].id(), address(vault)), 0, "morpho.supplyShares(2)");
        assertEq(vault.idle(), INITIAL_DEPOSIT, "vault.idle() 1");
    }

    function testReallocateWithdrawSupply(uint256[3] memory withdraw, uint256[3] memory supply) public {
        uint256[3] memory sharesBefore = [
            morpho.supplyShares(allMarkets[0].id(), address(vault)),
            morpho.supplyShares(allMarkets[1].id(), address(vault)),
            morpho.supplyShares(allMarkets[2].id(), address(vault))
        ];

        withdraw[0] = bound(withdraw[0], VIRTUAL_SHARES, sharesBefore[0]);
        withdraw[1] = bound(withdraw[1], VIRTUAL_SHARES, sharesBefore[1]);
        withdraw[2] = bound(withdraw[2], VIRTUAL_SHARES, sharesBefore[2]);

        withdrawn.push(MarketAllocation(allMarkets[0], 0, withdraw[0]));
        withdrawn.push(MarketAllocation(allMarkets[1], 0, withdraw[1]));
        withdrawn.push(MarketAllocation(allMarkets[2], 0, withdraw[2]));

        uint256 expectedIdle;
        (supply, expectedIdle) = _boundSupply(withdraw, supply);

        supplied.push(MarketAllocation(allMarkets[0], 0, supply[0]));
        supplied.push(MarketAllocation(allMarkets[1], 0, supply[1]));
        supplied.push(MarketAllocation(allMarkets[2], 0, supply[2]));

        vm.prank(ALLOCATOR);
        vault.reallocate(withdrawn, supplied);

        assertEq(
            morpho.supplyShares(allMarkets[0].id(), address(vault)),
            sharesBefore[0] - withdraw[0] + supply[0],
            "morpho.supplyShares(0)"
        );
        assertEq(
            morpho.supplyShares(allMarkets[1].id(), address(vault)),
            sharesBefore[1] - withdraw[1] + supply[1],
            "morpho.supplyShares(1)"
        );
        assertEq(
            morpho.supplyShares(allMarkets[2].id(), address(vault)),
            sharesBefore[2] - withdraw[2] + supply[2],
            "morpho.supplyShares(2)"
        );
        assertEq(vault.idle(), expectedIdle, "vault.idle() 1");
    }

    function _boundSupply(uint256[3] memory withdraw, uint256[3] memory supply)
        internal
        view
        returns (uint256[3] memory, uint256 availableForSupply)
    {
        uint256[3] memory totalSupplyAssets;
        uint256[3] memory totalSupplyShares;
        (totalSupplyAssets[0], totalSupplyShares[0],,) = morpho.expectedMarketBalances(allMarkets[0]);
        (totalSupplyAssets[1], totalSupplyShares[1],,) = morpho.expectedMarketBalances(allMarkets[1]);
        (totalSupplyAssets[2], totalSupplyShares[2],,) = morpho.expectedMarketBalances(allMarkets[2]);

        uint256[3] memory withdrawAssets;
        withdrawAssets[0] = withdraw[0].toAssetsDown(totalSupplyAssets[0], totalSupplyShares[0]);
        withdrawAssets[1] = withdraw[1].toAssetsDown(totalSupplyAssets[1], totalSupplyShares[1]);
        withdrawAssets[2] = withdraw[2].toAssetsDown(totalSupplyAssets[2], totalSupplyShares[2]);

        uint256 available = withdrawAssets[0] + withdrawAssets[1] + withdrawAssets[2] + vault.idle();

        uint256[3] memory supplyAssetsAfter;
        supplyAssetsAfter[0] = totalSupplyAssets[0] - withdrawAssets[0];
        supplyAssetsAfter[1] = totalSupplyAssets[1] - withdrawAssets[1];
        supplyAssetsAfter[2] = totalSupplyAssets[2] - withdrawAssets[2];

        uint256[3] memory sharesAfter;
        sharesAfter[0] = totalSupplyShares[0] - withdraw[0];
        sharesAfter[1] = totalSupplyShares[1] - withdraw[1];
        sharesAfter[2] = totalSupplyShares[2] - withdraw[2];

        supply[0] = bound(
            supply[0],
            1,
            UtilsLib.min(available, CAP2 - supplyAssetsAfter[0]).toSharesDown(supplyAssetsAfter[0], sharesAfter[0])
        );
        available -= supply[0].toAssetsUp(supplyAssetsAfter[0], sharesAfter[0]);

        supply[1] = bound(
            supply[1],
            1,
            UtilsLib.min(available, CAP2 - supplyAssetsAfter[1]).toSharesDown(supplyAssetsAfter[1], sharesAfter[1])
        );
        available -= supply[1].toAssetsUp(supplyAssetsAfter[1], sharesAfter[1]);

        supply[2] = bound(
            supply[2],
            1,
            UtilsLib.min(available, CAP2 - supplyAssetsAfter[2]).toSharesDown(supplyAssetsAfter[2], sharesAfter[2])
        );
        available -= supply[2].toAssetsUp(supplyAssetsAfter[2], sharesAfter[2]);

        return (supply, available);
    }
}
