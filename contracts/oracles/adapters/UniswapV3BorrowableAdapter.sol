// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

abstract contract UniswapV3BorrowableAdapter {
    IUniswapV3Pool public immutable UNI_V3_BORROWABLE_POOL;
    uint32 public immutable UNI_V3_BORROWABLE_DELAY;

    constructor(address pool, uint32 delay) {
        UNI_V3_BORROWABLE_POOL = IUniswapV3Pool(pool);
        UNI_V3_BORROWABLE_DELAY = delay;
    }
}
