// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {IChainlinkAggregatorV3, ChainlinkL2Adapter} from "./adapters/ChainlinkL2Adapter.sol";

contract ChainlinkL2Oracle is BaseOracle, ChainlinkCollateralAdapter, ChainlinkL2Adapter {
    constructor(
        uint256 priceScale,
        address collateralFeed,
        IChainlinkAggregatorV3 sequencerUptimeFeed,
        uint256 gracePeriod
    )
        BaseOracle(priceScale)
        ChainlinkCollateralAdapter(collateralFeed)
        ChainlinkL2Adapter(sequencerUptimeFeed, gracePeriod)
    {}

    function collateralPrice() public view override(BaseOracle, ChainlinkCollateralAdapter) returns (uint256) {
        return _CHAINLINK_COLLATERAL_FEED.price(SEQUENCER_UPTIME_FEED, GRACE_PERIOD);
    }
}
