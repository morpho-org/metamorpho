// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";

struct MarketAllocation {
    MarketParams marketParams;
    uint256 assets;
}
