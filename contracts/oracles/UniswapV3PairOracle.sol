// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";
import {UniswapV3BorrowableAdapter} from "./adapters/UniswapV3BorrowableAdapter.sol";

contract UniswapV3Oracle is BaseOracle, UniswapV3CollateralAdapter, UniswapV3BorrowableAdapter {
    constructor(
        address collateralPool,
        address borrowablePool,
        uint32 collateralPriceDelay,
        uint32 borrowablePriceDelay,
        uint256 priceScale
    )
        BaseOracle(priceScale)
        UniswapV3CollateralAdapter(collateralPool, collateralPriceDelay)
        UniswapV3BorrowableAdapter(borrowablePool, borrowablePriceDelay)
    {}

    function collateralScale() public view override(BaseOracle, UniswapV3CollateralAdapter) returns (uint256) {
        return super.collateralScale();
    }

    function borrowableScale() public view override(BaseOracle, UniswapV3BorrowableAdapter) returns (uint256) {
        return super.borrowableScale();
    }

    function collateralToBasePrice() public view override(BaseOracle, UniswapV3CollateralAdapter) returns (uint256) {
        return super.collateralToBasePrice();
    }

    function borrowableToBasePrice() public view override(BaseOracle, UniswapV3BorrowableAdapter) returns (uint256) {
        return super.borrowableToBasePrice();
    }
}
