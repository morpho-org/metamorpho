// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";
import {UniswapV3BorrowableAdapter} from "./adapters/UniswapV3BorrowableAdapter.sol";

contract UniswapV3Oracle is BaseOracle, UniswapV3CollateralAdapter, UniswapV3BorrowableAdapter {
    constructor(
        uint256 scaleFactor,
        address collateralPool,
        address borrowablePool,
        uint32 collateralPriceDelay,
        uint32 borrowablePriceDelay
    )
        BaseOracle(scaleFactor)
        UniswapV3CollateralAdapter(collateralPool, collateralPriceDelay)
        UniswapV3BorrowableAdapter(borrowablePool, borrowablePriceDelay)
    {}
}
