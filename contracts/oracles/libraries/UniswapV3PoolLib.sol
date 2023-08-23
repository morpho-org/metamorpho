// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";
import {TickMath} from "@uniswap/v3-core/libraries/TickMath.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

/// @title UniswapV3PoolLib
/// @notice Provides functions to integrate with a V3 pool, as an oracle.
library UniswapV3PoolLib {
    /// @notice Calculates the weighted arithmetic mean tick of a pool over a given duration.
    /// @dev The weighted arithmetic mean tick corresponds to the weighted geometric mean price.
    /// @dev Warning: assumes `secondsAgo` to be non-zero.
    function getWeightedArithmeticMeanTick(IUniswapV3Pool pool, uint32 secondsAgo)
        internal
        view
        returns (int24 weightedArithmeticMeanTick)
    {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

        weightedArithmeticMeanTick = int24(tickCumulativesDelta / int56(uint56(secondsAgo)));
        // Always round to negative infinity
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(secondsAgo)) != 0)) {
            weightedArithmeticMeanTick--;
        }
    }

    /// @notice Calculates the time-weighted average price of a pool over a given duration, optionally inversed.
    /// @param pool Address of the pool that we want to observe.
    /// @param secondsAgo Number of seconds in the past from which to calculate the time-weighted average.
    /// @param inversed True to query the price of token1 quoted in token0. False to query the price of token0 quoted in
    /// token1.
    /// @return The time-weighted average price from (block.timestamp - secondsAgo) to block.timestamp.
    function priceX128(IUniswapV3Pool pool, uint32 secondsAgo, bool inversed) internal view returns (uint256) {
        int24 weightedArithmeticMeanTick = getWeightedArithmeticMeanTick(pool, secondsAgo);

        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(weightedArithmeticMeanTick);

        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;

            return inversed
                ? FullMath.mulDiv(1 << 192, 1 << 128, ratioX192)
                : FullMath.mulDiv(ratioX192, 1 << 128, 1 << 192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);

            return inversed ? FullMath.mulDiv(1 << 128, 1 << 128, ratioX128) : ratioX128;
        }
    }
}
