// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";
import {TickMath} from "@uniswap/v3-core/libraries/TickMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

/// @title UniswapV3PoolLib
/// @notice Provides functions to integrate with a V3 pool, as an oracle.
library UniswapV3PoolLib {
    using FullMath for uint256;

    /// @notice Calculates the weighted arithmetic mean tick of a pool over a given duration.
    /// @dev Note that the weighted arithmetic mean tick corresponds to the weighted geometric mean price.
    function getWeightedArithmeticMeanTick(IUniswapV3Pool pool, uint32 secondsAgo)
        internal
        pure
        returns (int24 weightedArithmeticMeanTick)
    {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives,) = IUniswapV3Pool(pool).observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

        weightedArithmeticMeanTick = int24(tickCumulativesDelta / secondsAgo);
        // Always round to negative infinity
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % secondsAgo != 0)) weightedArithmeticMeanTick--;
    }

    /// @notice Calculates the time-weighted average price of a pool over a given duration, optionally inversed.
    /// @param pool Address of the pool that we want to observe.
    /// @param secondsAgo Number of seconds in the past from which to calculate the time-weighted average.
    /// @param scale The desired end price scale.
    /// @param inversed True to query the price of token1 quoted in token0. False to query the price of token0 quoted in token1.
    /// @return The time-weighted average price from (block.timestamp - secondsAgo) to block.timestamp.
    function price(IUniswapV3Pool pool, uint32 secondsAgo, uint256 scale, bool inversed)
        internal
        view
        returns (uint256)
    {
        int24 weightedArithmeticMeanTick = getWeightedArithmeticMeanTick(pool, secondsAgo);

        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(weightedArithmeticMeanTick);
        uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);

        return inversed ? scale.mulDiv(ratioX128, 1 << 128) : scale.mulDiv(1 << 128, ratioX128);
    }
}
