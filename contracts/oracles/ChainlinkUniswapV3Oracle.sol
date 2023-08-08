// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OracleFeed, IOracle} from "./interfaces/IOracle.sol";

import {FixedPointMathLib} from "@morpho-blue/libraries/FixedPointMathLib.sol";

import {UniswapV3Adapter} from "./adapters/UniswapV3Adapter.sol";
import {ChainlinkAggregatorAdapter} from "./adapters/ChainlinkAggregatorAdapter.sol";

contract ChainlinkUniswapV3Oracle is ChainlinkAggregatorAdapter, UniswapV3Adapter, IOracle {
    using FixedPointMathLib for uint256;

    constructor(address chainlinkFeed, uint256 chainlinkPriceScale, address uniV3Pool, uint32 uniV3Delay, uint256 scale)
        ChainlinkAggregatorAdapter(chainlinkFeed, chainlinkPriceScale)
        UniswapV3Adapter(uniV3Pool, uniV3Delay)
    {}

    function FEED1() external view returns (OracleFeed, address) {
        return (OracleFeed.CHAINLINK, address(_CHAINLINK_FEED));
    }

    function FEED2() external view returns (OracleFeed, address) {
        return (OracleFeed.UNISWAP_V3, address(_UNI_V3_POOL));
    }

    function price() external view returns (uint256, uint256) {
        return (
            (_chainlinkPrice() * FixedPointMathLib.WAD).divWadDown(_uniV3Price() * _CHAINLINK_PRICE_SCALE),
            FixedPointMathLib.WAD
        );
    }
}
