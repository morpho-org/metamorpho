// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "@morpho-blue/interfaces/IOracle.sol";

import {ERC20Mock} from "@morpho-blue/mocks/ERC20Mock.sol";
import {OracleMock} from "@morpho-blue/mocks/OracleMock.sol";

import "./BaseTest.sol";

abstract contract LocalTest is BaseTest {
    using MathLib for uint256;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;
    using stdStorage for StdStorage;

    uint256 internal constant LLTV = 0.8 ether;

    ERC20Mock internal borrowableToken;
    ERC20Mock internal collateralToken;
    IOracle internal oracle;

    MarketParams internal marketParams;
    Id internal id;

    function setUp() public virtual override {
        super.setUp();

        borrowableToken = new ERC20Mock("borrowable", "B");
        collateralToken = new ERC20Mock("collateral", "C");

        OracleMock oracleMock = new OracleMock();
        oracle = oracleMock;

        oracleMock.setPrice(ORACLE_PRICE_SCALE);

        marketParams =
            MarketParams(address(borrowableToken), address(collateralToken), address(oracle), address(irm), LLTV);
        id = marketParams.id();

        vm.startPrank(OWNER);
        morpho.enableLltv(LLTV);
        morpho.createMarket(marketParams);
        vm.stopPrank();

        borrowableToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);

        vm.prank(SUPPLIER);
        borrowableToken.approve(address(morpho), type(uint256).max);
    }
}
