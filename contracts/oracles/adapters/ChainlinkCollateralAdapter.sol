// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {OracleFeed} from "../libraries/OracleFeed.sol";
import {ChainlinkAggregatorV3Lib} from "../libraries/ChainlinkAggregatorV3Lib.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract ChainlinkCollateralAdapter is BaseOracle {
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    IChainlinkAggregatorV3 internal immutable _CHAINLINK_COLLATERAL_FEED;
    uint256 internal immutable _CHAINLINK_COLLATERAL_RANGE_FACTOR;

    constructor(address feed, uint256 rangeFactor) {
        require(feed != address(0), ErrorsLib.ZERO_ADDRESS);

        _CHAINLINK_COLLATERAL_FEED = IChainlinkAggregatorV3(feed);
        COLLATERAL_SCALE = 10 ** _CHAINLINK_COLLATERAL_FEED.decimals();
        _CHAINLINK_COLLATERAL_RANGE_FACTOR = rangeFactor;
    }

    function COLLATERAL_FEED() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(_CHAINLINK_COLLATERAL_FEED));
    }

    function collateralPrice() public view virtual override returns (uint256) {
        return _CHAINLINK_COLLATERAL_FEED.price(_CHAINLINK_COLLATERAL_RANGE_FACTOR);
    }
}
