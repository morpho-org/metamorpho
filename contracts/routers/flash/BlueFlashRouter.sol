// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IBlueFlashLoanCallback} from "@morpho-blue/interfaces/IBlueCallbacks.sol";
import {IBlue} from "@morpho-blue/interfaces/IBlue.sol";

import {Errors} from "./libraries/Errors.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseFlashRouter} from "./BaseFlashRouter.sol";

/// @title BlueFlashRouter.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
abstract contract BlueFlashRouter is BaseFlashRouter, IBlueFlashLoanCallback {
    using SafeTransferLib for ERC20;

    /* IMMUTABLES */

    IBlue internal immutable _BLUE;

    /* CONSTRUCTOR */

    constructor(address blue) {
        require(blue != address(0), Errors.ZERO_ADDRESS);

        _BLUE = IBlue(blue);
    }

    /* CALLBACKS */

    function onBlueFlashLoan(address, uint256, bytes calldata data) external {
        _onCallback(data);
    }

    /* ACTIONS */

    /// @dev Triggers a flash loan on Blue.
    function blueFlashLoan(address asset, uint256 amount, bytes calldata data) external {
        _approveMaxBlue(asset);

        _BLUE.flashLoan(asset, amount, data);
    }

    /* PRIVATE */

    /// @dev Gives the max approval to the Morpho contract to spend the given `asset` if not already approved.
    function _approveMaxBlue(address asset) private {
        if (ERC20(asset).allowance(address(this), address(_BLUE)) == 0) {
            ERC20(asset).safeApprove(address(_BLUE), type(uint256).max);
        }
    }
}
