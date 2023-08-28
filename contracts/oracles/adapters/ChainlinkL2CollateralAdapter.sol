// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "./interfaces/IChainlinkAggregatorV3.sol";

import {ChainlinkAggregatorV3Lib} from "./libraries/ChainlinkAggregatorV3Lib.sol";

import {ChainlinkL2BaseAdapter} from "./ChainlinkL2BaseAdapter.sol";
import {ChainlinkCollateralAdapter} from "./ChainlinkCollateralAdapter.sol";

abstract contract ChainlinkL2CollateralAdapter is ChainlinkL2BaseAdapter, ChainlinkCollateralAdapter {
    using ChainlinkAggregatorV3Lib for IChainlinkAggregatorV3;

    function collateralPrice() public view virtual override returns (uint256) {
        return _CHAINLINK_COLLATERAL_FEED.price(COLLATERAL_BOUND_OFFSET_FACTOR, SEQUENCER_UPTIME_FEED, GRACE_PERIOD);
    }
}
