// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IBaseBulker} from "./interfaces/IBaseBulker.sol";

import {Errors} from "./libraries/Errors.sol";

import {Multicall} from "./Multicall.sol";

/// @title BaseBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
/// @notice Base abstract contract allowing to dispatch a batch of actions down the inheritance tree.
abstract contract BaseBulker is Multicall, IBaseBulker {
    /* STORAGE */

    /// @dev Keeps track of the bulker's latest batch initiator. Also prevents interacting with the bulker outside of an initiated execution context.
    address private _initiator;

    /* MODIFIERS */

    modifier lockInitiator() {
        _initiator = msg.sender;

        _;

        delete _initiator;
    }

    modifier callback(bytes calldata data) {
        _checkInitiated();

        _multicall(abi.decode(data, (bytes[])));

        _;
    }

    /* INTERNAL */

    function _checkInitiated() internal view {
        require(_initiator != address(0), Errors.ALREADY_INITIATED);
    }
}
