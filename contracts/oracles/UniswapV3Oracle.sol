// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {StaticBorrowableAdapter} from "./adapters/StaticBorrowableAdapter.sol";
import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";

contract UniswapV3Oracle is BaseOracle, UniswapV3CollateralAdapter, StaticBorrowableAdapter {
    constructor(uint256 priceScale, address pool, uint32 window, address quoteToken)
        BaseOracle(priceScale)
        UniswapV3CollateralAdapter(pool, window, quoteToken)
    {}
}
