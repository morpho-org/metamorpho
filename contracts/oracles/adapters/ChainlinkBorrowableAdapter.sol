// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";

import {OracleFeed} from "../libraries/OracleFeed.sol";
import {ChainlinkAggregatorV3Lib} from "../libraries/ChainlinkAggregatorV3Lib.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract ChainlinkBorrowableAdapter is BaseOracle {
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    IChainlinkAggregatorV3 private immutable _CHAINLINK_BORROWABLE_FEED;
    uint256 private immutable _BORROWABLE_SCALE;

    constructor(address feed) {
        _CHAINLINK_BORROWABLE_FEED = IChainlinkAggregatorV3(feed);
        _BORROWABLE_SCALE = 10 ** _CHAINLINK_BORROWABLE_FEED.decimals();
    }

    function BORROWABLE_FEED() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(_CHAINLINK_BORROWABLE_FEED));
    }

    function BORROWABLE_SCALE() public view virtual override returns (uint256) {
        return _BORROWABLE_SCALE;
    }

    function borrowablePrice() public view virtual override returns (uint256) {
        return _CHAINLINK_BORROWABLE_FEED.price();
    }
}
