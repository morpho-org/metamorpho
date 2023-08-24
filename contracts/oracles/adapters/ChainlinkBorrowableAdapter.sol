// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {OracleFeed} from "../libraries/OracleFeed.sol";
import {ChainlinkAggregatorV3Lib} from "../libraries/ChainlinkAggregatorV3Lib.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract ChainlinkBorrowableAdapter is BaseOracle {
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    IChainlinkAggregatorV3 internal immutable _CHAINLINK_BORROWABLE_FEED;
    uint256 internal immutable _CHAINLINK_BORROWABLE_RELATIVE_PRICE_LIMIT;

    constructor(address feed, uint256 relativePriceLimit) {
        require(feed != address(0), ErrorsLib.ZERO_ADDRESS);

        _CHAINLINK_BORROWABLE_FEED = IChainlinkAggregatorV3(feed);
        BORROWABLE_SCALE = 10 ** _CHAINLINK_BORROWABLE_FEED.decimals();
        _CHAINLINK_BORROWABLE_RELATIVE_PRICE_LIMIT = relativePriceLimit;
    }

    function BORROWABLE_FEED() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(_CHAINLINK_BORROWABLE_FEED));
    }

    function borrowablePrice() public view virtual override returns (uint256) {
        return _CHAINLINK_BORROWABLE_FEED.price(_CHAINLINK_BORROWABLE_RELATIVE_PRICE_LIMIT);
    }
}
