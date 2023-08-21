// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "./adapters/interfaces/IChainlinkAggregatorV3.sol";

import {BaseOracle} from "./BaseOracle.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract ChainlinkPairOracleL2 is BaseOracle, ChainlinkCollateralAdapter, ChainlinkBorrowableAdapter {
    /// @dev The feed that provides the uptime of the sequencer.
    IChainlinkAggregatorV3 public immutable SEQUENCER_UPTIME_FEED;

    /// @dev Grace period during which the oracle reverts after a sequencer downtime.
    uint256 public immutable GRACE_PERIOD;

    constructor(
        uint256 priceScale,
        address collateralFeed,
        address borrowableFeed,
        IChainlinkAggregatorV3 sequencerUptimeFeed,
        uint256 gracePeriod
    ) BaseOracle(priceScale) ChainlinkCollateralAdapter(collateralFeed) ChainlinkBorrowableAdapter(borrowableFeed) {
        require(address(sequencerUptimeFeed) != address(0), "ChainlinkPairOracleL2: invalid sequencer uptime feed");
        require(gracePeriod > 0, "ChainlinkPairOracleL2: invalid grace period");

        SEQUENCER_UPTIME_FEED = sequencerUptimeFeed;
        GRACE_PERIOD = gracePeriod;
    }
}
