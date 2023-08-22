// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";
import {UniswapV3BorrowableAdapter} from "./adapters/UniswapV3BorrowableAdapter.sol";

contract UniswapV3Oracle is BaseOracle, UniswapV3CollateralAdapter, UniswapV3BorrowableAdapter {
    constructor(
        uint256 priceScale,
        address collateralPool,
        address borrowablePool,
        uint32 collateralPriceDelay,
        uint32 borrowablePriceDelay,
        bool collateralPriceInversed,
        bool borrowablePriceInversed
    )
        BaseOracle(priceScale)
        UniswapV3CollateralAdapter(collateralPool, collateralPriceDelay, collateralPriceInversed)
        UniswapV3BorrowableAdapter(borrowablePool, borrowablePriceDelay, borrowablePriceInversed)
    {}
}
