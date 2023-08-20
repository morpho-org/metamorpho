// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IBorrowableAdapter} from "./interfaces/IBorrowableAdapter.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {OracleFeed} from "../libraries/OracleFeed.sol";
import {UniswapV3PoolLib} from "../libraries/UniswapV3PoolLib.sol";

abstract contract UniswapV3BorrowableAdapter is IBorrowableAdapter {
    using UniswapV3PoolLib for IUniswapV3Pool;

    IUniswapV3Pool public immutable UNI_V3_BORROWABLE_POOL;
    uint32 public immutable UNI_V3_BORROWABLE_DELAY;

    constructor(address pool, uint32 delay) {
        UNI_V3_BORROWABLE_POOL = IUniswapV3Pool(pool);
        UNI_V3_BORROWABLE_DELAY = delay;
    }

    function BORROWABLE_FEED() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(UNI_V3_BORROWABLE_POOL));
    }

    function borrowableScale() public view virtual returns (uint256) {
        return 1e18;
    }

    function borrowableToBasePrice() public view virtual returns (uint256) {
        return UNI_V3_BORROWABLE_POOL.price(UNI_V3_BORROWABLE_DELAY);
    }
}
