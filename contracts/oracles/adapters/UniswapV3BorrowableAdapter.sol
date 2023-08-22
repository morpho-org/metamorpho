// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {OracleFeed} from "../libraries/OracleFeed.sol";
import {UniswapV3PoolLib} from "../libraries/UniswapV3PoolLib.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract UniswapV3BorrowableAdapter is BaseOracle {
    using UniswapV3PoolLib for IUniswapV3Pool;

    IUniswapV3Pool private immutable _UNI_V3_BORROWABLE_POOL;
    uint32 private immutable _UNI_V3_BORROWABLE_DELAY;

    constructor(address pool, uint32 delay) {
        require(pool != address(0), ErrorsLib.ZERO_ADDRESS);
        require(delay > 0, ErrorsLib.ZERO_INPUT);

        _UNI_V3_BORROWABLE_POOL = IUniswapV3Pool(pool);
        _UNI_V3_BORROWABLE_DELAY = delay;
        BORROWABLE_SCALE = 1e18;
    }

    function BORROWABLE_FEED() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(_UNI_V3_BORROWABLE_POOL));
    }

    function BORROWABLE_DELAY() external view returns (uint32) {
        return _UNI_V3_BORROWABLE_DELAY;
    }

    function borrowablePrice() public view virtual override returns (uint256) {
        return _UNI_V3_BORROWABLE_POOL.price(_UNI_V3_BORROWABLE_DELAY);
    }
}
