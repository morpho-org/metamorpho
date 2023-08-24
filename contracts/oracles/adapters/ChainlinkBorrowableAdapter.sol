// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {OracleFeed} from "../libraries/OracleFeed.sol";
import {PercentageMath} from "@morpho-utils/math/PercentageMath.sol";
import {ChainlinkAggregatorV3Lib} from "../libraries/ChainlinkAggregatorV3Lib.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract ChainlinkBorrowableAdapter is BaseOracle {
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    IChainlinkAggregatorV3 internal immutable _CHAINLINK_BORROWABLE_FEED;

    uint256 public immutable BORROWABLE_BOUND_OFFSET_FACTOR;

    constructor(address feed, uint256 boundOffsetFactor) {
        require(feed != address(0), ErrorsLib.ZERO_ADDRESS);
        require(boundOffsetFactor <= PercentageMath.HALF_PERCENTAGE_FACTOR, ErrorsLib.INCORRECT_BOUND_OFFSET_FACTOR);

        _CHAINLINK_BORROWABLE_FEED = IChainlinkAggregatorV3(feed);
        BORROWABLE_SCALE = 10 ** _CHAINLINK_BORROWABLE_FEED.decimals();
        BORROWABLE_BOUND_OFFSET_FACTOR = boundOffsetFactor;
    }

    function BORROWABLE_FEED() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(_CHAINLINK_BORROWABLE_FEED));
    }

    function borrowablePrice() public view virtual override returns (uint256) {
        return _CHAINLINK_BORROWABLE_FEED.price(BORROWABLE_BOUND_OFFSET_FACTOR);
    }
}
