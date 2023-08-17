// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {Errors} from "./libraries/Errors.sol";

/// @title BaseCallbackReceiver
/// @notice Provides utility functions to identify the initiator of callbacks (which cannot be identified using `msg.sender` or `tx.origin`).
abstract contract BaseCallbackReceiver {
    /* STORAGE */

    /// @dev Keeps track of the bulker's latest batch initiator. Also prevents interacting with the bulker outside of an initiated execution context.
    address internal _initiator;

    /* MODIFIERS */

    modifier lockInitiator() {
        _initiator = msg.sender;

        _;

        delete _initiator;
    }

    /* INTERNAL */

    function _checkInitiated() internal view {
        require(_initiator != address(0), Errors.UNINITIATED);
    }
}
