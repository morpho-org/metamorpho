// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import {IChainlinkAggregatorV3} from "./adapters/interfaces/IChainlinkAggregatorV3.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";
import {WAD, MathLib} from "@morpho-blue/libraries/MathLib.sol";
import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";
import {UniswapV3PoolLib} from "./libraries/UniswapV3PoolLib.sol";
import {ChainlinkAggregatorV3Lib} from "./libraries/ChainlinkAggregatorV3Lib.sol";

import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {UniswapV3BorrowableAdapter} from "./adapters/UniswapV3BorrowableAdapter.sol";

contract ChainlinkUniswapV3Oracle is ChainlinkCollateralAdapter, UniswapV3BorrowableAdapter, IOracle {
    using MathLib for uint256;
    using UniswapV3PoolLib for IUniswapV3Pool;
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    /// @dev The scale must be 1e36 * 10^(decimals of borrowable token - decimals of collateral token).
    uint256 public immutable PRICE_SCALE;

    constructor(address feed, address pool, uint32 borrowablePriceDelay, uint256 scale)
        ChainlinkCollateralAdapter(feed)
        UniswapV3BorrowableAdapter(pool, borrowablePriceDelay)
    {
        PRICE_SCALE = scale;
    }

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(CHAINLINK_COLLATERAL_FEED));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(UNI_V3_BORROWABLE_POOL));
    }

    function price() external view returns (uint256) {
        return FullMath.mulDiv(
            CHAINLINK_COLLATERAL_FEED.price() * WAD,
            PRICE_SCALE, // Using FullMath to avoid overflowing because of PRICE_SCALE.
            UNI_V3_BORROWABLE_POOL.price(UNI_V3_BORROWABLE_DELAY) * CHAINLINK_COLLATERAL_PRICE_SCALE
        );
    }
}
