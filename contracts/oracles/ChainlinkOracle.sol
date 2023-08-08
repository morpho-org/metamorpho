// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";

import {ChainlinkAggregatorAdapter} from "./adapters/ChainlinkAggregatorAdapter.sol";

contract ChainlinkOracle is ChainlinkAggregatorAdapter, IOracle {
    constructor(address feed, uint256 scale) ChainlinkAggregatorAdapter(feed, scale) {}

    function FEED1() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK, address(_CHAINLINK_FEED));
    }

    function FEED2() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK, address(_CHAINLINK_FEED));
    }

    function price() external view returns (uint256, uint256) {
        return (_chainlinkPrice(), _CHAINLINK_PRICE_SCALE);
    }
}
