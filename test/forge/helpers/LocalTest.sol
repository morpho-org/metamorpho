// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MarketLib} from "@morpho-blue/libraries/MarketLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";
import {FixedPointMathLib, WAD} from "@morpho-blue/libraries/FixedPointMathLib.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {ERC20Mock} from "test/forge/mocks/ERC20Mock.sol";

import "./BaseTest.sol";

abstract contract LocalTest is BaseTest {
    using MarketLib for Market;
    using SharesMathLib for uint256;
    using stdStorage for StdStorage;
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    uint256 internal constant LLTV = 0.8 ether;

    ERC20Mock internal borrowableAsset;
    ERC20Mock internal collateralAsset;
    OracleMock internal oracle;

    Market internal market;
    Id internal id;

    function setUp() public virtual override {
        super.setUp();

        // List a market.
        borrowableAsset = new ERC20Mock("borrowable", "B", 18);
        collateralAsset = new ERC20Mock("collateral", "C", 18);
        oracle = new OracleMock();

        market = Market(address(borrowableAsset), address(collateralAsset), address(oracle), address(irm), LLTV);
        id = market.id();

        oracle.setPrice(ORACLE_PRICE_SCALE);

        vm.startPrank(OWNER);
        morpho.enableLltv(LLTV);
        morpho.createMarket(market);
        vm.stopPrank();

        borrowableAsset.approve(address(morpho), type(uint256).max);
        collateralAsset.approve(address(morpho), type(uint256).max);

        vm.prank(SUPPLIER);
        borrowableAsset.approve(address(morpho), type(uint256).max);
    }
}