// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {IChainlinkAggregatorV3} from "./adapters/interfaces/IChainlinkAggregatorV3.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";
import {MathLib} from "@morpho-blue/libraries/MathLib.sol";
import {UniswapV3PoolLib} from "./libraries/UniswapV3PoolLib.sol";
import {ChainlinkAggregatorLib} from "./libraries/ChainlinkAggregatorLib.sol";

import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract UniswapV3ChainlinkOracle is UniswapV3CollateralAdapter, ChainlinkBorrowableAdapter, IOracle {
    using MathLib for uint256;
    using UniswapV3PoolLib for IUniswapV3Pool;
    using ChainlinkAggregatorLib for IChainlinkAggregatorV3;

    constructor(address pool, address feed, uint32 collateralPriceDelay, uint256 borrowablePriceScale)
        UniswapV3CollateralAdapter(pool, collateralPriceDelay)
        ChainlinkBorrowableAdapter(feed, borrowablePriceScale)
    {}

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(UNI_V3_COLLATERAL_POOL));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK, address(CHAINLINK_BORROWABLE_FEED));
    }

    function price() external view returns (uint256) {
        return UNI_V3_COLLATERAL_POOL.price(UNI_V3_COLLATERAL_DELAY).wDivDown(CHAINLINK_BORROWABLE_FEED.price()); // TODO: incorrect formula
    }
}
