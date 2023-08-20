// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";

contract ChainlinkOracle is BaseOracle, ChainlinkCollateralAdapter {
    constructor(address feed, uint256 priceScale) BaseOracle(priceScale) ChainlinkCollateralAdapter(feed) {}

    function BORROWABLE_FEED() external view returns (string memory, address) {}

    function BORROWABLE_SCALE() external pure returns (uint256) {
        return 1e18;
    }

    function borrowableToBasePrice() external pure returns (uint256) {
        return 1e18;
    }
}
