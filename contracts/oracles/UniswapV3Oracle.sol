// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";
import {UniswapV3PoolLib} from "./libraries/UniswapV3PoolLib.sol";

import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";

contract UniswapV3Oracle is UniswapV3CollateralAdapter, IOracle {
    using UniswapV3PoolLib for IUniswapV3Pool;

    constructor(address pool, uint32 delay) UniswapV3CollateralAdapter(pool, delay) {}

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(UNI_V3_COLLATERAL_POOL));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {}

    function price() external view returns (uint256) {
        return UNI_V3_COLLATERAL_POOL.price(UNI_V3_COLLATERAL_DELAY);
    }
}
