// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "../adapters/interfaces/IChainlinkAggregatorV3.sol";

library ChainlinkAggregatorV3Lib {
    function price(IChainlinkAggregatorV3 priceFeed, uint256 staleTimeout) internal view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();

        require(answer > 0, "ChainlinkAggregatorV3Lib: price is negative");

        require(block.timestamp - updatedAt <= staleTimeout, "ChainlinkAggregatorV3Lib: price is stale");

        return uint256(answer);
    }

    function price(
        IChainlinkAggregatorV3 priceFeed,
        uint256 staleTimeout,
        IChainlinkAggregatorV3 sequencerUptimeFeed,
        uint256 gracePeriod
    ) internal view returns (uint256) {
        (, int256 answer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();

        // answer == 0: Sequencer is up.
        // answer == 1: Sequencer is down.
        require(answer == 0, "ChainlinkAggregatorV3Lib: sequencer is down");

        // Make sure the grace period has passed after the sequencer is back up.
        require(block.timestamp - startedAt > gracePeriod, "ChainlinkAggregatorV3Lib: grace period not over");

        return price(priceFeed, staleTimeout);
    }
}
