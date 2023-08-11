// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IMulticall} from "./interfaces/IMulticall.sol";

import {Errors} from "./libraries/Errors.sol";

import {BaseSelfMulticall} from "../BaseSelfMulticall.sol";
import {BaseCallbackDispatcher} from "../BaseCallbackDispatcher.sol";

/// @title BaseBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
abstract contract BaseBulker is BaseSelfMulticall, BaseCallbackDispatcher {
    /* EXTERNAL */

    function multicall(uint256 deadline, bytes[] calldata data)
        external
        payable
        lockInitiator
        returns (bytes[] memory)
    {
        require(block.timestamp <= deadline, Errors.DEADLINE_EXPIRED);

        return _multicall(data);
    }

    function callBulker(address bulker, bytes[] calldata data) external {
        require(bulker != address(0), Errors.ZERO_ADDRESS);

        IMulticall(bulker).multicall(block.timestamp, data);
    }
}
