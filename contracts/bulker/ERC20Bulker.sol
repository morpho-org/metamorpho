// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {ERC20 as ERC20Permit2, Permit2Lib} from "@permit2/libraries/Permit2Lib.sol";

import {BaseBulker} from "./BaseBulker.sol";

/// @title ERC20Bulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
/// @notice Contract allowing to bundle multiple interactions with ERC20s together.
contract ERC20Bulker is BaseBulker {
    using Permit2Lib for ERC20Permit2;

    /* PRIVATE */

    /// @dev Approves the given `amount` of `asset` from sender to be spent by this contract via Permit2 with the given `deadline` & EIP712 `signature`.
    function _approve2(bytes memory data) private {
        (address asset, uint256 amount, uint256 deadline, Signature memory signature) =
            abi.decode(data, (address, uint256, uint256, Signature));
        if (amount == 0) revert AmountIsZero();

        ERC20Permit2(asset).simplePermit2(
            msg.sender, address(this), amount, deadline, signature.v, signature.r, signature.s
        );
    }

    /// @dev Transfers the given `amount` of `asset` from sender to this contract via ERC20 transfer with Permit2 fallback.
    function _transferFrom2(bytes memory data) private {
        (address asset, uint256 amount) = abi.decode(data, (address, uint256));
        if (amount == 0) revert AmountIsZero();

        ERC20Permit2(asset).transferFrom2(msg.sender, address(this), amount);
    }
}
