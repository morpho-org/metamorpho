// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {IChainlinkAggregator} from "./adapters/interfaces/IChainlinkAggregator.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";
import {UniswapV3PoolLib} from "./libraries/UniswapV3PoolLib.sol";
import {ChainlinkAggregatorLib} from "./libraries/ChainlinkAggregatorLib.sol";
import {FixedPointMathLib} from "@morpho-blue/libraries/FixedPointMathLib.sol";

import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {UniswapV3BorrowableAdapter} from "./adapters/UniswapV3BorrowableAdapter.sol";

contract ChainlinkUniswapV3Oracle is ChainlinkCollateralAdapter, UniswapV3BorrowableAdapter, IOracle {
    using UniswapV3PoolLib for IUniswapV3Pool;
    using ChainlinkAggregatorLib for IChainlinkAggregator;
    using FixedPointMathLib for uint256;

    constructor(address feed, address pool, uint256 collateralPriceScale, uint32 borrowablePriceDelay)
        ChainlinkCollateralAdapter(feed, collateralPriceScale)
        UniswapV3BorrowableAdapter(pool, borrowablePriceDelay)
    {}

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK, address(CHAINLINK_COLLATERAL_FEED));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(UNI_V3_BORROWABLE_POOL));
    }

    function price() external view returns (uint256, uint256) {
        return (
            CHAINLINK_COLLATERAL_FEED.price().divWadDown(UNI_V3_BORROWABLE_POOL.price(UNI_V3_BORROWABLE_DELAY)),
            CHAINLINK_COLLATERAL_PRICE_SCALE
        );
    }
}
