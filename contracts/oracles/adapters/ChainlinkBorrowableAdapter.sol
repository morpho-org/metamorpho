// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IBorrowableAdapter} from "./interfaces/IBorrowableAdapter.sol";
import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";

import {OracleFeed} from "../libraries/OracleFeed.sol";
import {ChainlinkAggregatorV3Lib} from "../libraries/ChainlinkAggregatorV3Lib.sol";

abstract contract ChainlinkBorrowableAdapter is IBorrowableAdapter {
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    IChainlinkAggregatorV3 public immutable CHAINLINK_BORROWABLE_FEED;
    uint256 public immutable BORROWABLE_SCALE;

    constructor(address feed) {
        CHAINLINK_BORROWABLE_FEED = IChainlinkAggregatorV3(feed);
        BORROWABLE_SCALE = 10 ** CHAINLINK_BORROWABLE_FEED.decimals();
    }

    function BORROWABLE_FEED() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(CHAINLINK_BORROWABLE_FEED));
    }

    function borrowableToBasePrice() public view returns (uint256) {
        return CHAINLINK_BORROWABLE_FEED.price();
    }
}
