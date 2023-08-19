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

import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract UniswapV3ChainlinkOracle is UniswapV3CollateralAdapter, ChainlinkBorrowableAdapter, IOracle {
    using MathLib for uint256;
    using UniswapV3PoolLib for IUniswapV3Pool;
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    /// @dev The scale must be 1e36 * 10^(decimals of borrowable token - decimals of collateral token).
    uint256 public immutable PRICE_SCALE;

    constructor(address pool, address feed, uint32 collateralPriceDelay, uint256 scale)
        UniswapV3CollateralAdapter(pool, collateralPriceDelay)
        ChainlinkBorrowableAdapter(feed)
    {
        PRICE_SCALE = scale;
    }

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(UNI_V3_COLLATERAL_POOL));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(CHAINLINK_BORROWABLE_FEED));
    }

    function price() external view returns (uint256) {
        return FullMath.mulDiv(
            UNI_V3_COLLATERAL_POOL.price(UNI_V3_COLLATERAL_DELAY) * CHAINLINK_BORROWABLE_PRICE_SCALE,
            PRICE_SCALE, // Using FullMath to avoid overflowing because of PRICE_SCALE.
            CHAINLINK_BORROWABLE_FEED.price() * WAD
        );
    }
}
