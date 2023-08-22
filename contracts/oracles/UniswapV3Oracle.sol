// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";

import {BaseOracle} from "./BaseOracle.sol";
import {StaticBorrowableAdapter} from "./adapters/StaticBorrowableAdapter.sol";
import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";

contract UniswapV3Oracle is BaseOracle, UniswapV3CollateralAdapter, StaticBorrowableAdapter {
    using FullMath for uint256;

    constructor(uint256 priceScale, address pool, uint32 delay, bool inversed)
        BaseOracle(priceScale)
        UniswapV3CollateralAdapter(pool, delay, inversed)
    {}
}
