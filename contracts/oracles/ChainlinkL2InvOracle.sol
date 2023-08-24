// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {ChainlinkL2BaseAdapter} from "./adapters/ChainlinkL2BaseAdapter.sol";
import {StaticCollateralAdapter} from "./adapters/StaticCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";
import {ChainlinkL2BorrowableAdapter} from "./adapters/ChainlinkL2BorrowableAdapter.sol";

contract ChainlinkLChainlinkL2InvOracle2Oracle is BaseOracle, StaticCollateralAdapter, ChainlinkL2BorrowableAdapter {
    constructor(
        uint256 priceScale,
        address collateralFeed,
        uint256 boundOffsetFactor,
        address sequencerUptimeFeed,
        uint256 gracePeriod
    )
        BaseOracle(priceScale)
        ChainlinkBorrowableAdapter(collateralFeed, boundOffsetFactor)
        ChainlinkL2BaseAdapter(sequencerUptimeFeed, gracePeriod)
    {}
}
