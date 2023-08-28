// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {ErrorsLib} from "./libraries/ErrorsLib.sol";

import {BaseSelfMulticall} from "../BaseSelfMulticall.sol";
import {BaseCallbackReceiver} from "../BaseCallbackReceiver.sol";

/// @title BaseBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Enables calling multiple functions in a single call to the same contract (self) as well as calling other
/// Bundler contracts.
/// @dev Every Bundler must inherit from this contract.
abstract contract BaseBundler is BaseSelfMulticall, BaseCallbackReceiver {
    /* EXTERNAL */

    /// @notice Executes a series of calls in a single transaction to self.
    function multicall(uint256 deadline, bytes[] calldata data)
        external
        payable
        lockInitiator
        returns (bytes[] memory)
    {
        require(block.timestamp <= deadline, ErrorsLib.DEADLINE_EXPIRED);

        return _multicall(data);
    }
}
