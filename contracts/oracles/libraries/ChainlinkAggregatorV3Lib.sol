// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "../adapters/interfaces/IChainlinkAggregatorV3.sol";
import {IChainlinkOffchainAggregator} from "../adapters/interfaces/IChainlinkOffchainAggregator.sol";

import {ErrorsLib} from "./ErrorsLib.sol";
import {PercentageMath} from "@morpho-utils/math/PercentageMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

library ChainlinkAggregatorV3Lib {
    using SafeCast for uint192;
    using PercentageMath for uint256;

    function price(IChainlinkAggregatorV3 priceFeed, uint256 relativePriceLimit)
        internal
        view
        returns (uint256 answer)
    {
        (, int256 answerIn,,,) = priceFeed.latestRoundData();

        require(answerIn > 0, ErrorsLib.NEGATIVE_VALUE);

        answer = uint256(answerIn);

        if (relativePriceLimit > 0) {
            address offchainFeed = priceFeed.aggregator();
            int192 minAnswerInt = IChainlinkOffchainAggregator(offchainFeed).minAnswer();
            int192 maxAnswerInt = IChainlinkOffchainAggregator(offchainFeed).maxAnswer();

            require(minAnswerInt > 0 && maxAnswerInt > 0, ErrorsLib.NEGATIVE_VALUE);

            uint256 minAnswer = uint192(minAnswerInt).toUint192();
            uint256 maxAnswer = uint192(maxAnswerInt).toUint192();

            require(
                answer >= minAnswer.percentAdd(relativePriceLimit) && answer <= maxAnswer.percentSub(relativePriceLimit),
                ErrorsLib.INVALID_ANSWER
            );
        }
    }

    function price(
        IChainlinkAggregatorV3 priceFeed,
        uint256 relativePriceLimit,
        IChainlinkAggregatorV3 sequencerUptimeFeed,
        uint256 gracePeriod
    ) internal view returns (uint256) {
        (, int256 answer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();

        // answer == 0: Sequencer is up.
        // answer == 1: Sequencer is down.
        require(answer == 0, ErrorsLib.SEQUENCER_DOWN);

        // Make sure the grace period has passed after the sequencer is back up.
        require(block.timestamp - startedAt > gracePeriod, ErrorsLib.GRACE_PERIOD_NOT_OVER);

        return price(priceFeed, relativePriceLimit);
    }
}
