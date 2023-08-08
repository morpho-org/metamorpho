// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IFlashBorrower} from "./interfaces/IFlashBorrower.sol";

import {Errors} from "./libraries/Errors.sol";

import {BaseSelfMulticall} from "../../BaseSelfMulticall.sol";

/// @title BaseFlashRouter.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
contract BaseFlashRouter is BaseSelfMulticall {
    /* STORAGE */

    /// @dev Keeps track of the bulker's latest batch initiator. Also prevents interacting with the bulker outside of an initiated execution context.
    address private _initiator;

    /* MODIFIERS */

    modifier lockInitiator() {
        _initiator = msg.sender;

        _;

        delete _initiator;
    }

    /* EXTERNAL */

    function flashLoan(bytes[] calldata data) external lockInitiator returns (bytes[] memory) {
        return _multicall(data);
    }

    /* INTERNAL */

    function _checkInitiated() internal view {
        require(_initiator != address(0), Errors.ALREADY_INITIATED);
    }

    function _onCallback(bytes calldata data) internal {
        _checkInitiated();

        bytes[] memory calls = abi.decode(data, (bytes[]));

        if (calls.length == 0) return IFlashBorrower(_initiator).onFlashLoan();

        _multicall(calls);
    }
}
