// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {IChainlinkAggregatorV3, ChainlinkL2Adapter} from "./adapters/ChainlinkL2Adapter.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract ChainlinkPairOracleL2 is
    BaseOracle,
    ChainlinkCollateralAdapter,
    ChainlinkBorrowableAdapter,
    ChainlinkL2Adapter
{
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
}
