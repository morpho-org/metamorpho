// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";

abstract contract ChainlinkCollateralAdapter {
    IChainlinkAggregatorV3 public immutable CHAINLINK_COLLATERAL_FEED;
    uint256 public immutable CHAINLINK_COLLATERAL_PRICE_SCALE;

    constructor(address feed) {
        CHAINLINK_COLLATERAL_FEED = IChainlinkAggregatorV3(feed);
        CHAINLINK_COLLATERAL_PRICE_SCALE = 10 ** CHAINLINK_COLLATERAL_FEED.decimals();
    }
}
