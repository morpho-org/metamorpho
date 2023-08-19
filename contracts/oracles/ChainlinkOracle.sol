// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";
import {IChainlinkAggregatorV3} from "./adapters/interfaces/IChainlinkAggregatorV3.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";
import {ChainlinkAggregatorLib} from "./libraries/ChainlinkAggregatorLib.sol";

import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";

contract ChainlinkOracle is ChainlinkCollateralAdapter, IOracle {
    using ChainlinkAggregatorLib for IChainlinkAggregatorV3;

    constructor(address feed, uint256 scale) ChainlinkCollateralAdapter(feed, scale) {}

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK, address(CHAINLINK_COLLATERAL_FEED));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {}

    function price() external view returns (uint256) {
        return CHAINLINK_COLLATERAL_FEED.price();
    }
}
