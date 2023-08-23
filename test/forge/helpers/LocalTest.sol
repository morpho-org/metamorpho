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

    ERC20Mock internal borrowableAsset;
    ERC20Mock internal collateralAsset;
    IOracle internal oracle;

    MarketParams internal marketParams;
    Id internal id;

    function setUp() public virtual override {
        super.setUp();

        // List a marketParams.
        borrowableAsset = new ERC20Mock("borrowable", "B");
        collateralAsset = new ERC20Mock("collateral", "C");
        oracle = new OracleMock();

        irm = new IrmMock(morpho);

        marketParams =
            MarketParams(address(borrowableAsset), address(collateralAsset), address(oracle), address(irm), LLTV);
        id = marketParams.id();

        OracleMock(address(oracle)).setPrice(ORACLE_PRICE_SCALE);

        vm.startPrank(OWNER);
        morpho.enableLltv(LLTV);
        morpho.enableIrm(address(irm));
        morpho.createMarket(marketParams);
        vm.stopPrank();

        borrowableAsset.approve(address(morpho), type(uint256).max);
        collateralAsset.approve(address(morpho), type(uint256).max);

        vm.prank(SUPPLIER);
        borrowableAsset.approve(address(morpho), type(uint256).max);
    }
}
