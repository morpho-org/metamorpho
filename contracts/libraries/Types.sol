// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Market} from "@morpho-blue/interfaces/IBlue.sol";

struct MarketAllocation {
    Market market;
    uint256 assets;
}

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}
