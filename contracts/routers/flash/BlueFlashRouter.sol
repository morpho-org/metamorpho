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

    IBlue public immutable BLUE;

    /* CONSTRUCTOR */

    constructor(address blue) {
        require(blue != address(0), Errors.ZERO_ADDRESS);

        BLUE = IBlue(blue);
    }

    /* CALLBACKS */

    function onBlueFlashLoan(uint256 amount, bytes calldata data) external {
        (address asset, bytes[] memory calls) = abi.decode(data, (address, bytes[]));

        _onCallback(calls);

        ERC20(asset).safeTransferFrom(_initiator, address(this), amount);
    }

    /* ACTIONS */

    /// @dev Triggers a flash loan on Blue.
    function blueFlashLoan(address asset, uint256 amount, bytes calldata data) external {
        _approveMax(asset, address(BLUE));

        BLUE.flashLoan(asset, amount, data);
    }
}
