// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {StaticCollateralAdapter} from "./adapters/StaticCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract ChainlinkOracle is BaseOracle, StaticCollateralAdapter, ChainlinkBorrowableAdapter {
    constructor(uint256 scaleFactor, address feed) BaseOracle(scaleFactor) ChainlinkBorrowableAdapter(feed) {}
}
