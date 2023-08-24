// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";
import {ChainlinkL2BaseAdapter} from "./adapters/ChainlinkL2BaseAdapter.sol";
import {ChainlinkL2CollateralAdapter} from "./adapters/ChainlinkL2CollateralAdapter.sol";
import {ChainlinkL2BorrowableAdapter} from "./adapters/ChainlinkL2BorrowableAdapter.sol";

contract ChainlinkL2PairOracle is BaseOracle, ChainlinkL2CollateralAdapter, ChainlinkL2BorrowableAdapter {
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
        ChainlinkL2BaseAdapter(sequencerUptimeFeed, gracePeriod)
    {}
}
