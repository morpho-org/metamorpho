// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {PercentageMath} from "@morpho-utils/math/PercentageMath.sol";
import {ChainlinkAggregatorV3Lib} from "./libraries/ChainlinkAggregatorV3Lib.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract ChainlinkCollateralAdapter is BaseOracle {
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    IChainlinkAggregatorV3 internal immutable _CHAINLINK_COLLATERAL_FEED;

    uint256 public immutable COLLATERAL_STALE_TIMEOUT;
    uint256 public immutable COLLATERAL_BOUND_OFFSET_FACTOR;

    constructor(address feed, uint256 staleTimeout, uint256 boundOffsetFactor) {
        require(feed != address(0), ErrorsLib.ZERO_ADDRESS);
        require(boundOffsetFactor <= PercentageMath.HALF_PERCENTAGE_FACTOR, ErrorsLib.INVALID_BOUND_OFFSET_FACTOR);

        _CHAINLINK_COLLATERAL_FEED = IChainlinkAggregatorV3(feed);
        COLLATERAL_STALE_TIMEOUT = staleTimeout;
        COLLATERAL_BOUND_OFFSET_FACTOR = boundOffsetFactor;

        COLLATERAL_SCALE = 10 ** _CHAINLINK_COLLATERAL_FEED.decimals();
    }

    function COLLATERAL_FEED() external view returns (address) {
        return address(_CHAINLINK_COLLATERAL_FEED);
    }

    function collateralPrice() public view virtual override returns (uint256) {
        return _CHAINLINK_COLLATERAL_FEED.price(COLLATERAL_STALE_TIMEOUT, COLLATERAL_BOUND_OFFSET_FACTOR);
    }
}
