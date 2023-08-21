// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ChainlinkAggregatorV3Lib} from "./libraries/ChainlinkAggregatorV3Lib.sol";

import {BaseOracle} from "./BaseOracle.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";
import {IChainlinkAggregatorV3, ChainlinkL2Adapter} from "./adapters/ChainlinkL2Adapter.sol";

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
        IChainlinkAggregatorV3 sequencerUptimeFeed,
        uint256 gracePeriod
    )
        BaseOracle(priceScale)
        ChainlinkCollateralAdapter(collateralFeed)
        ChainlinkBorrowableAdapter(borrowableFeed)
        ChainlinkL2Adapter(sequencerUptimeFeed, gracePeriod)
    {}

    function collateralToBasePrice() public view override(BaseOracle, ChainlinkCollateralAdapter) returns (uint256) {
        return CHAINLINK_COLLATERAL_FEED.price(SEQUENCER_UPTIME_FEED, GRACE_PERIOD);
    }

    function borrowableToBasePrice() public view override(BaseOracle, ChainlinkBorrowableAdapter) returns (uint256) {
        return CHAINLINK_BORROWABLE_FEED.price(SEQUENCER_UPTIME_FEED, GRACE_PERIOD);
    }
}
