// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";
import {IChainlinkAggregator} from "./adapters/interfaces/IChainlinkAggregator.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";
import {ChainlinkAggregatorLib} from "./libraries/ChainlinkAggregatorLib.sol";

import {ChainlinkCollateralAdapter} from "./adapters/ChainlinkCollateralAdapter.sol";

contract ChainlinkOracle is ChainlinkCollateralAdapter, IOracle {
    using ChainlinkAggregatorLib for IChainlinkAggregator;

    constructor(address feed, uint256 scale) ChainlinkCollateralAdapter(feed, scale) {}

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK, address(CHAINLINK_FEED_COLLATERAL));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {}

    function price() external view returns (uint256, uint256) {
        return (CHAINLINK_FEED_COLLATERAL.price(), CHAINLINK_COLLATERAL_PRICE_SCALE);
    }
}
