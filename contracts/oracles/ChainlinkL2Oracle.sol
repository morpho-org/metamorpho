// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {StaticBorrowableAdapter} from "./adapters/StaticBorrowableAdapter.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {ChainlinkL2BaseAdapter} from "./adapters/ChainlinkL2BaseAdapter.sol";
import {ChainlinkL2CollateralAdapter} from "./adapters/ChainlinkL2CollateralAdapter.sol";

contract ChainlinkL2Oracle is BaseOracle, ChainlinkL2CollateralAdapter, StaticBorrowableAdapter {
    constructor(uint256 priceScale, address collateralFeed, address sequencerUptimeFeed, uint256 gracePeriod)
        BaseOracle(priceScale)
        ChainlinkCollateralAdapter(collateralFeed)
        ChainlinkL2BaseAdapter(sequencerUptimeFeed, gracePeriod)
    {}
}
