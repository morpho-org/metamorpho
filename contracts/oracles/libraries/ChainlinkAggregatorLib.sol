// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregator} from "../adapters/interfaces/IChainlinkAggregator.sol";

library ChainlinkAggregatorLib {
    function price(IChainlinkAggregator aggregator) internal view returns (uint256) {
        return uint256(aggregator.latestAnswer());
    }
}
