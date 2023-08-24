// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {StaticBorrowableAdapter} from "./adapters/StaticBorrowableAdapter.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";

contract ChainlinkOracle is BaseOracle, ChainlinkCollateralAdapter, StaticBorrowableAdapter {
    constructor(uint256 scaleFactor, address feed, uint256 staleTimeout)
        BaseOracle(scaleFactor)
        ChainlinkCollateralAdapter(feed, staleTimeout)
    {}
}
