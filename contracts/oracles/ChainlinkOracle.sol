// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {NeutralBorrowableAdapter} from "./adapters/NeutralBorrowableAdapter.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";

contract ChainlinkOracle is BaseOracle, ChainlinkCollateralAdapter, NeutralBorrowableAdapter {
    constructor(address feed, uint256 priceScale) BaseOracle(priceScale) ChainlinkCollateralAdapter(feed) {}

    function collateralScale() public view override(BaseOracle, ChainlinkCollateralAdapter) returns (uint256) {
        return super.collateralScale();
    }

    function borrowableScale() public view override(BaseOracle, NeutralBorrowableAdapter) returns (uint256) {
        return super.borrowableScale();
    }

    function collateralToBasePrice() public view override(BaseOracle, ChainlinkCollateralAdapter) returns (uint256) {
        return super.collateralToBasePrice();
    }

    function borrowableToBasePrice() public view override(BaseOracle, NeutralBorrowableAdapter) returns (uint256) {
        return super.borrowableToBasePrice();
    }
}
