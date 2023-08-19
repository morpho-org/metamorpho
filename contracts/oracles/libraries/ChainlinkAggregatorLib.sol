// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "../adapters/interfaces/IChainlinkAggregatorV3.sol";

library ChainlinkAggregatorLib {
    function price(IChainlinkAggregatorV3 aggregator) internal view returns (uint256) {
        (, int256 answer,,,) = aggregator.latestRoundData();
        return uint256(answer);
    }
}
