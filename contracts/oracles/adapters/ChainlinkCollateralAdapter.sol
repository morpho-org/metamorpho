// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregator} from "./interfaces/IChainlinkAggregator.sol";

abstract contract ChainlinkCollateralAdapter {
    IChainlinkAggregator public immutable CHAINLINK_FEED_COLLATERAL;
    uint256 public immutable CHAINLINK_COLLATERAL_PRICE_SCALE;

    constructor(address feed, uint256 scale) {
        CHAINLINK_FEED_COLLATERAL = IChainlinkAggregator(feed);
        CHAINLINK_COLLATERAL_PRICE_SCALE = scale;
    }
}
