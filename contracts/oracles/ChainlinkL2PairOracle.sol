// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3, ChainlinkAggregatorV3Lib} from "./libraries/ChainlinkAggregatorV3Lib.sol";

import {BaseOracle} from "./BaseOracle.sol";
import {ChainlinkL2Adapter} from "./adapters/ChainlinkL2Adapter.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract ChainlinkL2PairOracle is
    BaseOracle,
    ChainlinkCollateralAdapter,
    ChainlinkBorrowableAdapter,
    ChainlinkL2Adapter
{
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    constructor(
        uint256 priceScale,
        address collateralFeed,
        address borrowableFeed,
        address sequencerUptimeFeed,
        uint256 gracePeriod
    )
        BaseOracle(priceScale)
        ChainlinkCollateralAdapter(collateralFeed)
        ChainlinkBorrowableAdapter(borrowableFeed)
        ChainlinkL2Adapter(sequencerUptimeFeed, gracePeriod)
    {}

    function collateralPrice() public view override(BaseOracle, ChainlinkCollateralAdapter) returns (uint256) {
        return _CHAINLINK_COLLATERAL_FEED.price(SEQUENCER_UPTIME_FEED, GRACE_PERIOD);
    }

    function borrowablePrice() public view override(BaseOracle, ChainlinkBorrowableAdapter) returns (uint256) {
        return _CHAINLINK_BORROWABLE_FEED.price(SEQUENCER_UPTIME_FEED, GRACE_PERIOD);
    }
}
