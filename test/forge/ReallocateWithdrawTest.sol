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
    using MorphoLib for IMorpho;
    using SharesMathLib for uint256;
    using UtilsLib for uint256;

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

    function testReallocateWithdrawSupply(uint256[3] memory withdrawnShares, uint256[3] memory suppliedAssets) public {
        uint256[3] memory sharesBefore = [
            morpho.supplyShares(allMarkets[0].id(), address(vault)),
            morpho.supplyShares(allMarkets[1].id(), address(vault)),
            morpho.supplyShares(allMarkets[2].id(), address(vault))
        ];

        withdrawnShares[0] = bound(withdrawnShares[0], 0, sharesBefore[0]);
        withdrawnShares[1] = bound(withdrawnShares[1], 0, sharesBefore[1]);
        withdrawnShares[2] = bound(withdrawnShares[2], 0, sharesBefore[2]);

        uint256[3] memory totalSupplyAssets;
        uint256[3] memory totalSupplyShares;
        (totalSupplyAssets[0], totalSupplyShares[0],,) = morpho.expectedMarketBalances(allMarkets[0]);
        (totalSupplyAssets[1], totalSupplyShares[1],,) = morpho.expectedMarketBalances(allMarkets[1]);
        (totalSupplyAssets[2], totalSupplyShares[2],,) = morpho.expectedMarketBalances(allMarkets[2]);

        uint256[3] memory withdrawnAssets = [
            withdrawnShares[0].toAssetsDown(totalSupplyAssets[0], totalSupplyShares[0]),
            withdrawnShares[1].toAssetsDown(totalSupplyAssets[1], totalSupplyShares[1]),
            withdrawnShares[2].toAssetsDown(totalSupplyAssets[2], totalSupplyShares[2])
        ];

        if (withdrawnShares[0] > 0) withdrawn.push(MarketAllocation(allMarkets[0], 0, withdrawnShares[0]));
        if (withdrawnAssets[1] > 0) withdrawn.push(MarketAllocation(allMarkets[1], withdrawnAssets[1], 0));
        if (withdrawnShares[2] > 0) withdrawn.push(MarketAllocation(allMarkets[2], 0, withdrawnShares[2]));

        totalSupplyAssets[0] -= withdrawnAssets[0];
        totalSupplyAssets[1] -= withdrawnAssets[1];
        totalSupplyAssets[2] -= withdrawnAssets[2];

        totalSupplyShares[0] -= withdrawnShares[0];
        totalSupplyShares[1] -= withdrawnShares[1];
        totalSupplyShares[2] -= withdrawnShares[2];

        uint256 expectedIdle = vault.idle() + withdrawnAssets[0] + withdrawnAssets[1] + withdrawnAssets[2];

        suppliedAssets[0] = bound(suppliedAssets[0], 0, withdrawnAssets[0].zeroFloorSub(CAP2).min(expectedIdle));
        expectedIdle -= suppliedAssets[0];

        suppliedAssets[1] = bound(suppliedAssets[1], 0, withdrawnAssets[1].zeroFloorSub(CAP2).min(expectedIdle));
        expectedIdle -= suppliedAssets[1];

        suppliedAssets[2] = bound(suppliedAssets[2], 0, withdrawnAssets[2].zeroFloorSub(CAP2).min(expectedIdle));
        expectedIdle -= suppliedAssets[2];

        uint256[3] memory suppliedShares = [
            suppliedAssets[0].toSharesDown(totalSupplyAssets[0], totalSupplyShares[0]),
            suppliedAssets[1].toSharesDown(totalSupplyAssets[1], totalSupplyShares[1]),
            suppliedAssets[2].toSharesDown(totalSupplyAssets[2], totalSupplyShares[2])
        ];

        if (suppliedShares[0] > 0) supplied.push(MarketAllocation(allMarkets[0], suppliedAssets[0], 0));
        if (suppliedAssets[1] > 0) supplied.push(MarketAllocation(allMarkets[1], 0, suppliedShares[1]));
        if (suppliedShares[2] > 0) supplied.push(MarketAllocation(allMarkets[2], suppliedAssets[2], 0));

        vm.prank(ALLOCATOR);
        vault.reallocate(withdrawn, supplied);

        assertEq(
            morpho.supplyShares(allMarkets[0].id(), address(vault)),
            sharesBefore[0] - withdrawnShares[0] + suppliedShares[0],
            "morpho.supplyShares(0)"
        );
        assertApproxEqAbs(
            morpho.supplyShares(allMarkets[1].id(), address(vault)),
            sharesBefore[1] - withdrawnShares[1] + suppliedShares[1],
            SharesMathLib.VIRTUAL_SHARES,
            "morpho.supplyShares(1)"
        );
        assertEq(
            morpho.supplyShares(allMarkets[2].id(), address(vault)),
            sharesBefore[2] - withdrawnShares[2] + suppliedShares[2],
            "morpho.supplyShares(2)"
        );
        assertApproxEqAbs(vault.idle(), expectedIdle, 1, "vault.idle() 1");
    }
}
