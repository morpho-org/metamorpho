// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IBaseBulker} from "./interfaces/IBaseBulker.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

/// @title BaseBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
/// @notice Base abstract contract allowing to dispatch a batch of actions down the inheritance tree.
abstract contract BaseBulker is IBaseBulker {
    using SafeTransferLib for ERC20;

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

        _decodeExecute(data);

        _;
    }

    /* EXTERNAL */

    /// @notice Executes the given batch of actions, with the given input data.
    ///         Those actions, if not performed in the correct order, with the proper action's configuration
    ///         and with the proper inclusion of skim final calls, could leave funds in the Bulker contract.
    /// @param actions The batch of action to execute, one after the other.
    function execute(Action[] memory actions) external payable {
        _execute(actions);
    }

    /* INTERNAL */

    function _checkInitiated() internal view {
        require(_initiator != address(0), "2");
    }

    /// @notice Decodes and executes actions encoded as parameter.
    function _decodeExecute(bytes calldata data) internal {
        Action[] memory actions = _decodeActions(data);

        _execute(actions);
    }

    /// @notice Executes the given batch of actions, with the given input data.
    ///         Those actions, if not performed in the correct order, with the proper action's configuration
    ///         and with the proper inclusion of skim final calls, could leave funds in the Bulker contract.
    /// @param actions The batch of action to execute, one after the other.
    function _execute(Action[] memory actions) internal {
        uint256 nbActions = actions.length;
        for (uint256 i; i < nbActions; ++i) {
            Action memory action = actions[i];

            if (!_dispatch(action)) revert UnsupportedAction(action.actionType);
        }
    }

    /// @dev Performs the given action.
    /// @return Whether the action was successfully dispatched.
    function _dispatch(Action memory action) internal virtual returns (bool) {
        if (action.actionType == ActionType.SKIM) {
            _skim(action.data);

            return true;
        }

        return false;
    }

    /* PRIVATE */

    /// @notice Decodes the data passed as parameter as an array of actions.
    function _decodeActions(bytes calldata data) private pure returns (Action[] memory) {
        return abi.decode(data, (Action[]));
    }

    /// @dev Sends any ERC20 in this contract to the receiver.
    function _skim(bytes memory data) private {
        (address asset, address receiver) = abi.decode(data, (address, address));
        if (receiver == address(this)) revert AddressIsBulker();
        if (receiver == address(0)) revert AddressIsZero();

        uint256 balance = ERC20(asset).balanceOf(address(this));
        ERC20(asset).safeTransfer(receiver, balance);
    }
}
