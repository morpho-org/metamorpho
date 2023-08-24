// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract ChainlinkPairOracle is BaseOracle, ChainlinkCollateralAdapter, ChainlinkBorrowableAdapter {
    constructor(uint256 scaleFactor, address collateralFeed, address borrowableFeed, uint256 rangeFactor)
        BaseOracle(scaleFactor)
        ChainlinkCollateralAdapter(collateralFeed, rangeFactor)
        ChainlinkBorrowableAdapter(borrowableFeed, rangeFactor)
    {}
}
