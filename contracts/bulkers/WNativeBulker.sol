// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IWNative} from "../interfaces/IWNative.sol";

import {Errors} from "./libraries/Errors.sol";
import {Math} from "@morpho-utils/math/Math.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "./BaseBulker.sol";

/// @title WNativeBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
contract WNativeBulker is BaseBulker {
    using SafeTransferLib for ERC20;

    /* CONSTANTS */

    /// @dev The address of the WETH contract.
    address internal immutable _WRAPPED_NATIVE;

    /* CONSTRUCTOR */

    constructor(address wNative) {
        require(wNative != address(0), Errors.ZERO_ADDRESS);

        _WRAPPED_NATIVE = wNative;
    }

    /* CALLBACKS */

    /// @dev Only the WETH contract is allowed to transfer ETH to this contract, without any calldata.
    receive() external payable {
        require(msg.sender == _WRAPPED_NATIVE, Errors.ONLY_WNATIVE);
    }

    /* ACTIONS */

    /// @dev Wraps the given input of ETH to WETH.
    function wrapNative(uint256 amount) external {
        amount = Math.min(amount, address(this).balance);

        require(amount != 0, Errors.ZERO_AMOUNT);

        IWNative(_WRAPPED_NATIVE).deposit{value: amount}();
    }

    /// @dev Unwraps the given input of WETH to ETH.
    function unwrapNative(uint256 amount, address receiver) external {
        require(receiver != address(this), Errors.BULKER_ADDRESS);
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        amount = Math.min(amount, ERC20(_WRAPPED_NATIVE).balanceOf(address(this)));

        require(amount != 0, Errors.ZERO_AMOUNT);

        IWNative(_WRAPPED_NATIVE).withdraw(amount);

        SafeTransferLib.safeTransferETH(receiver, amount);
    }
}
