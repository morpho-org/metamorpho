// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3, ChainlinkAggregatorV3Lib} from "./libraries/ChainlinkAggregatorV3Lib.sol";

import {BaseOracle} from "./BaseOracle.sol";
import {ChainlinkL2Adapter} from "./adapters/ChainlinkL2Adapter.sol";
import {StaticBorrowableAdapter} from "./adapters/StaticBorrowableAdapter.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";

contract ChainlinkL2Oracle is BaseOracle, ChainlinkCollateralAdapter, StaticBorrowableAdapter, ChainlinkL2Adapter {
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    constructor(uint256 priceScale, address collateralFeed, address sequencerUptimeFeed, uint256 gracePeriod)
        BaseOracle(priceScale)
        ChainlinkCollateralAdapter(collateralFeed)
        ChainlinkL2Adapter(sequencerUptimeFeed, gracePeriod)
    {}

    function collateralPrice() public view override(BaseOracle, ChainlinkCollateralAdapter) returns (uint256) {
        return _CHAINLINK_COLLATERAL_FEED.price(SEQUENCER_UPTIME_FEED, GRACE_PERIOD);
    }
}
