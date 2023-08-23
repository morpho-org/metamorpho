// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "../adapters/interfaces/IChainlinkAggregatorV3.sol";
import {IChainlinkOffchainAggregator} from "../adapters/interfaces/IChainlinkOffchainAggregator.sol";

import {ErrorsLib} from "./ErrorsLib.sol";

library ChainlinkAggregatorV3Lib {
    function price(IChainlinkAggregatorV3 priceFeed) internal view returns (uint256) {
        (, int256 answer,,,) = priceFeed.latestRoundData();
        address offchainFeed = priceFeed.aggregator();

        int192 minAnswer = IChainlinkOffchainAggregator(offchainFeed).minAnswer();
        int192 maxAnswer = IChainlinkOffchainAggregator(offchainFeed).maxAnswer();

        require(answer >= minAnswer && answer <= maxAnswer, ErrorsLib.INVALID_ANSWER);

        return uint256(answer);
    }

    function price(IChainlinkAggregatorV3 priceFeed, IChainlinkAggregatorV3 sequencerUptimeFeed, uint256 gracePeriod)
        internal
        view
        returns (uint256)
    {
        (, int256 answer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();

        // answer == 0: Sequencer is up.
        // answer == 1: Sequencer is down.
        require(answer == 0, ErrorsLib.SEQUENCER_DOWN);

        // Make sure the grace period has passed after the sequencer is back up.
        require(block.timestamp - startedAt > gracePeriod, ErrorsLib.GRACE_PERIOD_NOT_OVER);

        return price(priceFeed);
    }
}
