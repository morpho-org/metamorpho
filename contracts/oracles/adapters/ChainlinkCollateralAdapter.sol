// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregator} from "./interfaces/IChainlinkAggregator.sol";

abstract contract ChainlinkCollateralAdapter {
    IChainlinkAggregator public immutable CHAINLINK_COLLATERAL_FEED;
    uint256 public immutable CHAINLINK_COLLATERAL_PRICE_SCALE;

    constructor(address feed, uint256 scale) {
        CHAINLINK_COLLATERAL_FEED = IChainlinkAggregator(feed);
        CHAINLINK_COLLATERAL_PRICE_SCALE = scale;
    }
}
