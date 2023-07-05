// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MarketKey} from "@morpho-blue/libraries/Types.sol";

struct MarketAllocation {
    MarketKey marketKey;
    uint256 assets;
}

struct MarketConfig {
    uint256 cap;
}

struct Market {
    uint256 rank;
    MarketConfig config;
}

struct ConfigSet {
    MarketKey[] markets;
    mapping(bytes32 marketId => Market) market;
}
