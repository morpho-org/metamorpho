// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregator} from "./interfaces/IChainlinkAggregator.sol";

abstract contract ChainlinkBorrowableAdapter {
    IChainlinkAggregator public immutable CHAINLINK_FEED_BORROWABLE;
    uint256 public immutable CHAINLINK_BORROWABLE_PRICE_SCALE;

    constructor(address feed, uint256 scale) {
        CHAINLINK_FEED_BORROWABLE = IChainlinkAggregator(feed);
        CHAINLINK_BORROWABLE_PRICE_SCALE = scale;
    }
}
