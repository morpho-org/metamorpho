// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IMulticall} from "./interfaces/IMulticall.sol";

import {SelfMulticall} from "./SelfMulticall.sol";

/// @title BaseBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
contract BaseBulker is SelfMulticall {
    /* EXTERNAL */

    function callBulker(IMulticall bulker, bytes[] calldata data) external {
        bulker.multicall(block.timestamp, data);
    }
}
