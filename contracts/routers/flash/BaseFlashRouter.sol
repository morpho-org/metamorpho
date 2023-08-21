// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IFlashBorrower} from "./interfaces/IFlashBorrower.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseSelfMulticall} from "../../BaseSelfMulticall.sol";
import {BaseCallbackReceiver} from "../../BaseCallbackReceiver.sol";

/// @title BaseFlashRouter.
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
abstract contract BaseFlashRouter is BaseSelfMulticall, BaseCallbackReceiver {
    using SafeTransferLib for ERC20;

    /* EXTERNAL */

    function flashLoan(bytes[] calldata data) external lockInitiator returns (bytes[] memory) {
        return _multicall(data);
    }

    /* INTERNAL */

    function _onCallback(bytes[] memory calls) internal {
        _checkInitiated();

        if (calls.length == 0) return IFlashBorrower(_initiator).onFlashLoan();

        _multicall(calls);
    }

    /// @dev Gives the max approval to the spender contract to spend the given `asset` if not already approved.
    function _approveMax(address asset, address spender) internal {
        if (ERC20(asset).allowance(address(this), spender) == 0) {
            ERC20(asset).safeApprove(spender, type(uint256).max);
        }
    }
}
