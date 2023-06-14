// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {InternalSupplyRouter} from "contracts/InternalSupplyRouter.sol";

contract SupplyRouter is InternalSupplyRouter {
    constructor(address factory) InternalSupplyRouter(factory) {}

    /* EXTERNAL */

    function supply(address asset, bytes calldata allocation, address onBehalf) external {
        _supply(asset, allocation, onBehalf);
    }

    function withdraw(address asset, bytes calldata allocation, address receiver) external {
        _withdraw(asset, allocation, receiver);
    }
}
