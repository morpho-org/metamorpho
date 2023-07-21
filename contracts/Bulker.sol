// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MarketAllocation} from "./libraries/Types.sol";

import {InternalSupplyRouter} from "contracts/InternalSupplyRouter.sol";

contract Bulker is InternalSupplyRouter {
    constructor(address factory) InternalSupplyRouter(factory) {}
}
