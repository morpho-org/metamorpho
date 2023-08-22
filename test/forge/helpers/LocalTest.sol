// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20Mock} from "test/forge/mocks/ERC20Mock.sol";

import "./BaseTest.sol";

abstract contract LocalTest is BaseTest {
    using MathLib for uint256;
    using SharesMathLib for uint256;
    using MarketLib for MarketParams;
    using stdStorage for StdStorage;

    uint256 internal constant LLTV = 0.8 ether;

    ERC20Mock internal borrowableAsset;
    ERC20Mock internal collateralAsset;
    OracleMock internal oracle;

    MarketParams internal marketParams;
    Id internal id;

    function setUp() public virtual override {
        super.setUp();

        // List a marketParams.
        borrowableAsset = new ERC20Mock("borrowable", "B", 18);
        collateralAsset = new ERC20Mock("collateral", "C", 18);
        oracle = new OracleMock();

        irm = new IrmMock(morpho);

        marketParams =
            MarketParams(address(borrowableAsset), address(collateralAsset), address(oracle), address(irm), LLTV);
        id = marketParams.id();

        oracle.setPrice(ORACLE_PRICE_SCALE);

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
