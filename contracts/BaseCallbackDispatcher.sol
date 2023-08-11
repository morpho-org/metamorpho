// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

/// @title BaseCallbackDispatcher
/// @notice Provides utility functions to identify the initiator of callbacks (which cannot be identified using `msg.sender` or `tx.origin`)
abstract contract BaseCallbackDispatcher {
    /* STORAGE */

    /// @dev Keeps track of the bulker's latest batch initiator. Also prevents interacting with the bulker outside of an initiated execution context.
    address internal _initiator;

    /* MODIFIERS */

    modifier lockInitiator() {
        _initiator = msg.sender;

        _;

        delete _initiator;
    }
}
