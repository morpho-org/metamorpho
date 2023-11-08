// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";

import "./helpers/IntegrationTest.sol";

uint256 constant CAP2 = 100e18;
uint256 constant INITIAL_DEPOSIT = 4 * CAP2;

contract ReallocateWithdrawTest is IntegrationTest {
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;
    using MorphoLib for IMorpho;
    using SharesMathLib for uint256;
    using UtilsLib for uint256;

    MarketAllocation[] internal allocations;

    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP2);
        _setCap(allMarkets[1], CAP2);
        _setCap(allMarkets[2], CAP2);

        loanToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);

        vm.prank(SUPPLIER);
        vault.deposit(INITIAL_DEPOSIT, ONBEHALF);
    }

    function testReallocateWithdrawMax() public {
        allocations.push(MarketAllocation(allMarkets[0], 0));
        allocations.push(MarketAllocation(allMarkets[1], 0));
        allocations.push(MarketAllocation(allMarkets[2], 0));

        vm.prank(ALLOCATOR);
        vault.reallocate(allocations);

        assertEq(morpho.supplyShares(allMarkets[0].id(), address(vault)), 0, "morpho.supplyShares(0)");
        assertEq(morpho.supplyShares(allMarkets[1].id(), address(vault)), 0, "morpho.supplyShares(1)");
        assertEq(morpho.supplyShares(allMarkets[2].id(), address(vault)), 0, "morpho.supplyShares(2)");
        assertEq(vault.idle(), INITIAL_DEPOSIT, "vault.idle() 1");
    }

    function testReallocateWithdrawInconsistentAsset() public {
        ERC20Mock loanToken2 = new ERC20Mock("loan2", "B2");
        allMarkets[0].loanToken = address(loanToken2);

        morpho.createMarket(allMarkets[0]);

        loanToken2.setBalance(SUPPLIER, 1);

        vm.startPrank(SUPPLIER);
        loanToken2.approve(address(morpho), type(uint256).max);
        morpho.supply(allMarkets[0], 1, 0, address(vault), hex"");
        vm.stopPrank();

        allocations.push(MarketAllocation(allMarkets[0], 0));

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.InconsistentAsset.selector, allMarkets[0].id()));
        vault.reallocate(allocations);
    }

    function testReallocateWithdrawSupply(uint256[3] memory assets) public {
        uint256[3] memory totalSupplyAssets;
        uint256[3] memory totalSupplyShares;
        (totalSupplyAssets[0], totalSupplyShares[0],,) = morpho.expectedMarketBalances(allMarkets[0]);
        (totalSupplyAssets[1], totalSupplyShares[1],,) = morpho.expectedMarketBalances(allMarkets[1]);
        (totalSupplyAssets[2], totalSupplyShares[2],,) = morpho.expectedMarketBalances(allMarkets[2]);

        assets[0] = bound(assets[0], 0, CAP2);
        assets[1] = bound(assets[1], 0, CAP2);
        assets[2] = bound(assets[2], 0, CAP2);

        allocations.push(MarketAllocation(allMarkets[0], assets[0]));
        allocations.push(MarketAllocation(allMarkets[1], assets[1]));
        allocations.push(MarketAllocation(allMarkets[2], assets[2]));

        uint256 expectedIdle = vault.idle() + 3 * CAP2 - assets[0] - assets[1] - assets[2];

        vm.prank(ALLOCATOR);
        vault.reallocate(allocations);

        assertEq(
            morpho.supplyShares(allMarkets[0].id(), address(vault)),
            assets[0] * SharesMathLib.VIRTUAL_SHARES,
            "morpho.supplyShares(0)"
        );
        assertApproxEqAbs(
            morpho.supplyShares(allMarkets[1].id(), address(vault)),
            assets[1] * SharesMathLib.VIRTUAL_SHARES,
            SharesMathLib.VIRTUAL_SHARES,
            "morpho.supplyShares(1)"
        );
        assertEq(
            morpho.supplyShares(allMarkets[2].id(), address(vault)),
            assets[2] * SharesMathLib.VIRTUAL_SHARES,
            "morpho.supplyShares(2)"
        );
        assertApproxEqAbs(vault.idle(), expectedIdle, 1, "vault.idle() 1");
    }

    function testReallocateUnauthorizedMarket(uint256[3] memory suppliedAssets) public {
        suppliedAssets[0] = bound(suppliedAssets[0], 1, CAP2);
        suppliedAssets[1] = bound(suppliedAssets[1], 1, CAP2);
        suppliedAssets[2] = bound(suppliedAssets[2], 1, CAP2);

        _setCap(allMarkets[1], 0);

        allocations.push(MarketAllocation(allMarkets[0], 0));
        allocations.push(MarketAllocation(allMarkets[1], 0));
        allocations.push(MarketAllocation(allMarkets[2], 0));

        allocations.push(MarketAllocation(allMarkets[0], suppliedAssets[0]));
        allocations.push(MarketAllocation(allMarkets[1], suppliedAssets[1]));
        allocations.push(MarketAllocation(allMarkets[2], suppliedAssets[2]));

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.UnauthorizedMarket.selector, allMarkets[1].id()));
        vault.reallocate(allocations);
    }

    function testReallocateSupplyCapExceeded() public {
        allocations.push(MarketAllocation(allMarkets[0], 0));
        allocations.push(MarketAllocation(allMarkets[1], 0));
        allocations.push(MarketAllocation(allMarkets[2], 0));

        allocations.push(MarketAllocation(allMarkets[0], CAP2 + 1));

        vm.prank(ALLOCATOR);
        vm.expectRevert(abi.encodeWithSelector(ErrorsLib.SupplyCapExceeded.selector, allMarkets[0].id()));
        vault.reallocate(allocations);
    }

    function testReallocateInsufficientIdle(uint256 rewards) public {
        rewards = bound(rewards, 1, MAX_TEST_ASSETS);

        address rewardDonator = makeAddr("reward donator");
        loanToken.setBalance(rewardDonator, rewards);
        vm.prank(rewardDonator);
        loanToken.transfer(address(vault), rewards);

        _setCap(allMarkets[0], type(uint192).max);

        allocations.push(MarketAllocation(allMarkets[0], 2 * CAP2 + rewards));

        vm.prank(ALLOCATOR);
        vm.expectRevert(ErrorsLib.InsufficientIdle.selector);
        vault.reallocate(allocations);
    }
}
