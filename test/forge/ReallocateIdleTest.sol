// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";

import "./helpers/IntegrationTest.sol";

uint256 constant CAP2 = 100e18;
uint256 constant INITIAL_DEPOSIT = 4 * CAP2;

contract ReallocateIdleTest is IntegrationTest {
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;

    MarketAllocation[] internal withdrawn;
    MarketAllocation[] internal supplied;

    function setUp() public override {
        super.setUp();

        loanToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);

        vm.prank(SUPPLIER);
        vault.deposit(INITIAL_DEPOSIT, ONBEHALF);

        _setCap(allMarkets[0], CAP2);
        _setCap(allMarkets[1], CAP2);
        _setCap(allMarkets[2], CAP2);

        _sortSupplyQueueIdleLast();
    }

    function testReallocateSupplyIdle(uint256[3] memory suppliedAssets) public {
        suppliedAssets[0] = bound(suppliedAssets[0], 1, CAP2);
        suppliedAssets[1] = bound(suppliedAssets[1], 1, CAP2);
        suppliedAssets[2] = bound(suppliedAssets[2], 1, CAP2);

        uint256 idleWithdrawn = suppliedAssets[0] + suppliedAssets[1] + suppliedAssets[2];

        withdrawn.push(MarketAllocation(_idleParams(), idleWithdrawn, 0));
        supplied.push(MarketAllocation(allMarkets[0], suppliedAssets[0], 0));
        supplied.push(MarketAllocation(allMarkets[1], suppliedAssets[1], 0));
        supplied.push(MarketAllocation(allMarkets[2], suppliedAssets[2], 0));

        uint256 idleBefore = _idle();

        vm.prank(ALLOCATOR);
        vault.reallocate(withdrawn, supplied);

        assertEq(
            morpho.supplyShares(allMarkets[0].id(), address(vault)),
            suppliedAssets[0] * SharesMathLib.VIRTUAL_SHARES,
            "morpho.supplyShares(0)"
        );
        assertEq(
            morpho.supplyShares(allMarkets[1].id(), address(vault)),
            suppliedAssets[1] * SharesMathLib.VIRTUAL_SHARES,
            "morpho.supplyShares(1)"
        );
        assertEq(
            morpho.supplyShares(allMarkets[2].id(), address(vault)),
            suppliedAssets[2] * SharesMathLib.VIRTUAL_SHARES,
            "morpho.supplyShares(2)"
        );

        assertApproxEqAbs(_idle(), idleBefore - idleWithdrawn, 3, "idle");
    }
}
