// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";
import {IChainlinkAggregator} from "./adapters/interfaces/IChainlinkAggregator.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";
import {ChainlinkAggregatorLib} from "./libraries/ChainlinkAggregatorLib.sol";
import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";

import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract ChainlinkOracle is ChainlinkCollateralAdapter, ChainlinkBorrowableAdapter, IOracle {
    using ChainlinkAggregatorLib for IChainlinkAggregator;

    uint256 public immutable PRICE_SCALE;

    constructor(
        address feedCollateral,
        address feedBorrowable,
        uint256 collateralPriceScale,
        uint256 borrowablePriceScale,
        uint256 scale
    )
        ChainlinkCollateralAdapter(feedCollateral, collateralPriceScale)
        ChainlinkBorrowableAdapter(feedBorrowable, borrowablePriceScale)
    {
        PRICE_SCALE = scale;
    }

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK, address(CHAINLINK_FEED_COLLATERAL));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK, address(CHAINLINK_FEED_BORROWABLE));
    }

    function price() external view returns (uint256, uint256) {
        return (
            FullMath.mulDiv(
                CHAINLINK_FEED_COLLATERAL.price() * CHAINLINK_BORROWABLE_PRICE_SCALE,
                PRICE_SCALE, // Using FullMath to avoid overflowing because of PRICE_SCALE.
                CHAINLINK_FEED_BORROWABLE.price() * CHAINLINK_COLLATERAL_PRICE_SCALE
                ),
            PRICE_SCALE
        );
    }
}
