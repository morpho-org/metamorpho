// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {UniswapV3OracleLib} from "./libraries/UniswapV3OracleLib.sol";

abstract contract UniswapV3Adapter {
    using UniswapV3OracleLib for IUniswapV3Pool;

    IUniswapV3Pool internal immutable _UNI_V3_POOL;

    uint32 private immutable _DELAY;

    constructor(address pool, uint32 delay) {
        _UNI_V3_POOL = IUniswapV3Pool(pool);
        _DELAY = delay;
    }

    function _uniV3Price() internal view returns (uint256) {
        return _UNI_V3_POOL.consult(_DELAY);
    }
}
