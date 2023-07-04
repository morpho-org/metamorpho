// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MarketKey, TrancheId} from "@morpho-blue/libraries/Types.sol";

struct MarketAllocation {
    MarketKey marketKey;
    TrancheId trancheId;
    uint256 assets;
}

struct MarketConfig {
    uint256 cap;
    TrancheId[] trancheIds;
}

struct Market {
    uint256 rank;
    MarketConfig config;
    mapping(TrancheId => uint256 rank) trancheRank;
}

struct ConfigSet {
    MarketKey[] markets;
    mapping(bytes32 marketId => Market) market;
}
