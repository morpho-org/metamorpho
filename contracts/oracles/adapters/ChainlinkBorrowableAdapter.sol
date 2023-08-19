// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";

abstract contract ChainlinkBorrowableAdapter {
    IChainlinkAggregatorV3 public immutable CHAINLINK_BORROWABLE_FEED;
    uint256 public immutable CHAINLINK_BORROWABLE_PRICE_SCALE;

    constructor(address feed) {
        CHAINLINK_BORROWABLE_FEED = IChainlinkAggregatorV3(feed);
        CHAINLINK_BORROWABLE_PRICE_SCALE = 10 ** CHAINLINK_BORROWABLE_FEED.decimals();
    }
}
