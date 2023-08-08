// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";

abstract contract ChainlinkAggregatorAdapter {
    IChainlinkAggregatorV3 internal immutable _CHAINLINK_FEED;

    uint256 internal immutable _CHAINLINK_PRICE_SCALE;

    constructor(address feed, uint256 scale) {
        _CHAINLINK_FEED = IChainlinkAggregatorV3(feed);
        _CHAINLINK_PRICE_SCALE = scale;
    }

    function _chainlinkPrice() internal view returns (uint256) {
        return uint256(_CHAINLINK_FEED.latestAnswer());
    }
}
