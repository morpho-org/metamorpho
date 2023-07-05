// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MarketAllocation} from "./libraries/Types.sol";

import {InternalSupplyRouter} from "contracts/InternalSupplyRouter.sol";

contract SupplyRouter is InternalSupplyRouter {
    constructor(address factory) InternalSupplyRouter(factory) {}

    /* EXTERNAL */

    function deposit(MarketAllocation[] calldata allocation, address onBehalf) external {
        _depositAll(allocation, onBehalf);
    }

    function withdraw(MarketAllocation[] calldata allocation, address onBehalf, address receiver) external {
        _withdrawAll(allocation, onBehalf, receiver);
    }
}
