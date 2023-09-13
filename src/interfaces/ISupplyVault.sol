// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.2;

import {MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";

struct MarketAllocation {
    MarketParams marketParams;
    uint256 assets;
}

struct Pending {
    uint128 value;
    uint128 timestamp;
}

interface IMetaMorpho {}
