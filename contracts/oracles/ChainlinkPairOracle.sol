// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract ChainlinkPairOracle is BaseOracle, ChainlinkCollateralAdapter, ChainlinkBorrowableAdapter {
    constructor(address collateralFeed, address borrowableFeed, uint256 priceScale)
        BaseOracle(priceScale)
        ChainlinkCollateralAdapter(collateralFeed)
        ChainlinkBorrowableAdapter(borrowableFeed)
    {}

    function collateralScale() public view override(BaseOracle, ChainlinkCollateralAdapter) returns (uint256) {
        return super.collateralScale();
    }

    function borrowableScale() public view override(BaseOracle, ChainlinkBorrowableAdapter) returns (uint256) {
        return super.borrowableScale();
    }

    function collateralToBasePrice() public view override(BaseOracle, ChainlinkCollateralAdapter) returns (uint256) {
        return super.collateralToBasePrice();
    }

    function borrowableToBasePrice() public view override(BaseOracle, ChainlinkBorrowableAdapter) returns (uint256) {
        return super.borrowableToBasePrice();
    }
}
