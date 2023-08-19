// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";
import {IChainlinkAggregatorV3} from "./adapters/interfaces/IChainlinkAggregatorV3.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";
import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";
import {ChainlinkAggregatorV3Lib} from "./libraries/ChainlinkAggregatorV3Lib.sol";

import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract ChainlinkOracle is ChainlinkCollateralAdapter, ChainlinkBorrowableAdapter, IOracle {
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    /// @dev The scale must be 1e36 * 10^(decimals of borrowable token - decimals of collateral token).
    uint256 public immutable PRICE_SCALE;

    constructor(address collateralFeed, address borrowableFeed, uint256 scale)
        ChainlinkCollateralAdapter(collateralFeed)
        ChainlinkBorrowableAdapter(borrowableFeed)
    {
        PRICE_SCALE = scale;
    }

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(CHAINLINK_COLLATERAL_FEED));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(CHAINLINK_BORROWABLE_FEED));
    }

    function price() external view returns (uint256) {
        return FullMath.mulDiv(
            CHAINLINK_COLLATERAL_FEED.price() * CHAINLINK_BORROWABLE_PRICE_SCALE,
            PRICE_SCALE, // Using FullMath to avoid overflowing because of PRICE_SCALE.
            CHAINLINK_BORROWABLE_FEED.price() * CHAINLINK_COLLATERAL_PRICE_SCALE
        );
    }
}
