// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";

import "./helpers/BaseTest.sol";

uint256 constant CAP2 = 100e18;
uint256 constant INITIAL_DEPOSIT = 4 * CAP2;

contract ReallocateTest is BaseTest {
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

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(new Id[](0));

        borrowableToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);

        vm.prank(SUPPLIER);
        vault.deposit(INITIAL_DEPOSIT, ONBEHALF);
    }

    function testReallocateSupplyIdle(uint256[3] memory suppliedShares) public {
        suppliedShares[0] = bound(suppliedShares[0], VIRTUAL_SHARES, CAP2 * VIRTUAL_SHARES);
        suppliedShares[1] = bound(suppliedShares[1], VIRTUAL_SHARES, CAP2 * VIRTUAL_SHARES);
        suppliedShares[2] = bound(suppliedShares[2], VIRTUAL_SHARES, CAP2 * VIRTUAL_SHARES);

        supplied.push(MarketAllocation(allMarkets[0], 0, suppliedShares[0]));
        supplied.push(MarketAllocation(allMarkets[1], 0, suppliedShares[1]));
        supplied.push(MarketAllocation(allMarkets[2], 0, suppliedShares[2]));

        uint256 idleBefore = vault.idle();

        vm.prank(ALLOCATOR);
        vault.reallocate(withdrawn, supplied);

        assertEq(morpho.supplyShares(allMarkets[0].id(), address(vault)), suppliedShares[0], "morpho.supplyShares(0)");
        assertEq(morpho.supplyShares(allMarkets[1].id(), address(vault)), suppliedShares[1], "morpho.supplyShares(1)");
        assertEq(morpho.supplyShares(allMarkets[2].id(), address(vault)), suppliedShares[2], "morpho.supplyShares(2)");

        uint256 expectedIdle = idleBefore - suppliedShares[0] / VIRTUAL_SHARES - suppliedShares[1] / VIRTUAL_SHARES
            - suppliedShares[2] / VIRTUAL_SHARES;
        assertApproxEqAbs(vault.idle(), expectedIdle, 3, "vault.idle() 1");
    }
}
