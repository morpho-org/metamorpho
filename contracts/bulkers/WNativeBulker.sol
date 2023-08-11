// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IWNative} from "./interfaces/IWNative.sol";

import {Errors} from "./libraries/Errors.sol";
import {Math} from "@morpho-utils/math/Math.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "./BaseBulker.sol";

/// @title WNativeBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
abstract contract WNativeBulker is BaseBulker {
    using SafeTransferLib for ERC20;

    /* CONSTANTS */

    /// @dev The address of the wrapped native token contract.
    address public immutable WRAPPED_NATIVE;

    /* CONSTRUCTOR */

    constructor(address wNative) {
        require(wNative != address(0), Errors.ZERO_ADDRESS);

        WRAPPED_NATIVE = wNative;
    }

    /* CALLBACKS */

    /// @dev Only the wNative contract is allowed to transfer the native token to this contract, without any calldata.
    receive() external payable {
        require(msg.sender == WRAPPED_NATIVE, Errors.ONLY_WNATIVE);
    }

    /* ACTIONS */

    /// @dev Wraps the given `amount` of the native token to wNative and sends it to `receiver`.
    function wrapNative(uint256 amount, address receiver) external {
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        amount = Math.min(amount, address(this).balance);

        require(amount != 0, Errors.ZERO_AMOUNT);

        IWNative(WRAPPED_NATIVE).deposit{value: amount}();

        if (receiver != address(this)) ERC20(WRAPPED_NATIVE).safeTransfer(receiver, amount);
    }

    /// @dev Unwraps the given `amount` of wNative to the native token and sends it to `receiver`.
    function unwrapNative(uint256 amount, address receiver) external {
        require(receiver != address(this), Errors.BULKER_ADDRESS);
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        amount = Math.min(amount, ERC20(WRAPPED_NATIVE).balanceOf(address(this)));

        require(amount != 0, Errors.ZERO_AMOUNT);

        IWNative(WRAPPED_NATIVE).withdraw(amount);

        SafeTransferLib.safeTransferETH(receiver, amount);
    }
}
