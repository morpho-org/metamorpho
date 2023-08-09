// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IMulticall} from "./interfaces/IMulticall.sol";

import {Errors} from "./libraries/Errors.sol";

import {BaseSelfMulticall} from "../BaseSelfMulticall.sol";

/// @title SelfMulticall
/// @notice Enables calling multiple functions in a single call to the same contract.
abstract contract SelfMulticall is BaseSelfMulticall, IMulticall {
    /* EXTERNAL */

    function multicall(uint256 deadline, bytes[] calldata data) external payable returns (bytes[] memory) {
        require(block.timestamp <= deadline, Errors.DEADLINE_EXPIRED);

        return _multicall(data);
    }
}
