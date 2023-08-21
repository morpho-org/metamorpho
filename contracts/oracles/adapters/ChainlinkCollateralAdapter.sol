// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";

import {OracleFeed} from "../libraries/OracleFeed.sol";
import {ChainlinkAggregatorV3Lib} from "../libraries/ChainlinkAggregatorV3Lib.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract ChainlinkCollateralAdapter is BaseOracle {
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    IChainlinkAggregatorV3 private immutable CHAINLINK_COLLATERAL_FEED;
    uint256 private immutable COLLATERAL_SCALE;

    constructor(address feed) {
        CHAINLINK_COLLATERAL_FEED = IChainlinkAggregatorV3(feed);
        COLLATERAL_SCALE = 10 ** CHAINLINK_COLLATERAL_FEED.decimals();
    }

    function COLLATERAL_FEED() external view returns (string memory, address) {
        return (OracleFeed.CHAINLINK_V3, address(CHAINLINK_COLLATERAL_FEED));
    }

    function collateralScale() public view virtual override returns (uint256) {
        return COLLATERAL_SCALE;
    }

    function collateralToBasePrice() public view virtual override returns (uint256) {
        return CHAINLINK_COLLATERAL_FEED.price();
    }
}
