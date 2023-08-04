// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IWNative} from "../interfaces/IWNative.sol";
import {IWNativeBulker} from "./interfaces/IWNativeBulker.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "./BaseBulker.sol";

/// @title WNativeBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
/// @notice Contract allowing to bundle multiple interactions with stETH together.
contract WNativeBulker is BaseBulker, IWNativeBulker {
    using SafeTransferLib for ERC20;

    /* CONSTANTS */

    /// @dev The address of the WETH contract.
    address internal immutable _WRAPPED_NATIVE;

    /* CONSTRUCTOR */

    constructor(address wNative) {
        if (wNative == address(0)) revert AddressIsZero();

        _WRAPPED_NATIVE = wNative;
    }

    /* EXTERNAL */

    /// @dev Only the WETH contract is allowed to transfer ETH to this contract, without any calldata.
    receive() external payable {
        if (msg.sender != _WRAPPED_NATIVE) revert OnlyWNative();
    }

    /* PRIVATE */

    /// @dev Wraps the given input of ETH to WETH.
    function _wrapNative(bytes memory data) private {
        (uint256 amount) = abi.decode(data, (uint256));

        amount = Math.min(amount, address(this).balance);
        if (amount == 0) revert AmountIsZero();

        IWNative(_WRAPPED_NATIVE).deposit{value: amount}();
    }

    /// @dev Unwraps the given input of WETH to ETH.
    function _unwrapNative(bytes memory data) private {
        (uint256 amount, address receiver) = abi.decode(data, (uint256, address));
        if (receiver == address(this)) revert AddressIsBulker();
        if (receiver == address(0)) revert AddressIsZero();

        amount = Math.min(amount, ERC20(_WRAPPED_NATIVE).balanceOf(address(this)));
        if (amount == 0) revert AmountIsZero();

        IWNative(_WRAPPED_NATIVE).withdraw(amount);

        SafeTransferLib.safeTransferETH(receiver, amount);
    }
}
