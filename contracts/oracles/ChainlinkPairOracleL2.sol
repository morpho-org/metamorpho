// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";
import {IChainlinkAggregatorV3} from "./adapters/interfaces/IChainlinkAggregatorV3.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";
import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";
import {ChainlinkAggregatorV3Lib} from "./libraries/ChainlinkAggregatorV3Lib.sol";

import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract ChainlinkPairOracleL2 is ChainlinkCollateralAdapter, ChainlinkBorrowableAdapter, IOracle {
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    /// @dev The scale must be 1e36 * 10^(decimals of borrowable token - decimals of collateral token).
    uint256 public immutable PRICE_SCALE;

    /// @dev The feed that provides the uptime of the sequencer.
    IChainlinkAggregatorV3 public immutable SEQUENCER_UPTIME_FEED;

    /// @dev Grace period during which the oracle reverts after a sequencer downtime.
    uint256 public immutable GRACE_PERIOD;

    constructor(
        address collateralFeed,
        address borrowableFeed,
        uint256 scale,
        IChainlinkAggregatorV3 sequencerUptimeFeed,
        uint256 gracePeriod
    ) ChainlinkCollateralAdapter(collateralFeed) ChainlinkBorrowableAdapter(borrowableFeed) {
        require(collateralFeed != address(0), "ChainlinkPairOracleL2: invalid collateral feed");
        require(borrowableFeed != address(0), "ChainlinkPairOracleL2: invalid borrowable feed");
        require(scale > 0, "ChainlinkPairOracleL2: invalid scale");
        require(address(sequencerUptimeFeed) != address(0), "ChainlinkPairOracleL2: invalid sequencer uptime feed");
        require(gracePeriod > 0, "ChainlinkPairOracleL2: invalid grace period");

        PRICE_SCALE = scale;
        SEQUENCER_UPTIME_FEED = sequencerUptimeFeed;
        GRACE_PERIOD = gracePeriod;
    }

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(CHAINLINK_COLLATERAL_FEED));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(CHAINLINK_BORROWABLE_FEED));
    }

    function price() external view returns (uint256) {
        return FullMath.mulDiv(
            CHAINLINK_COLLATERAL_FEED.price(SEQUENCER_UPTIME_FEED, GRACE_PERIOD) * CHAINLINK_BORROWABLE_PRICE_SCALE,
            PRICE_SCALE, // Using FullMath to avoid overflowing because of PRICE_SCALE.
            CHAINLINK_BORROWABLE_FEED.price(SEQUENCER_UPTIME_FEED, GRACE_PERIOD) * CHAINLINK_COLLATERAL_PRICE_SCALE
        );
    }
}
