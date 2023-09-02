// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {Signature} from "@morpho-blue/interfaces/IMorpho.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {Math} from "@morpho-utils/math/Math.sol";
import {SafeTransferLib, ERC20} from "solmate/src/utils/SafeTransferLib.sol";
import {ERC20 as ERC20Permit2, Permit2Lib} from "@permit2/libraries/Permit2Lib.sol";

import {BaseBundler} from "./BaseBundler.sol";

/// @title ERC20Bundler
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Bundler contract managing interactions with ERC20 compliant tokens.
/// @dev It leverages Uniswap's Permit2 contract.
abstract contract ERC20Bundler is BaseBundler {
    using SafeTransferLib for ERC20;
    using Permit2Lib for ERC20Permit2;

    /* ACTIONS */

    /// @dev Transfers the minimum between the given `amount` and the bundler balance of `asset` from this contract to
    /// `recipient`.
    function transfer(address asset, address recipient, uint256 amount) external payable {
        require(recipient != address(0), ErrorsLib.ZERO_ADDRESS);
        require(recipient != address(this), ErrorsLib.BUNDLER_ADDRESS);

        amount = Math.min(amount, ERC20(asset).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        ERC20(asset).safeTransfer(recipient, amount);
    }

    /// @dev Approves the given `amount` of `asset` from sender to be spent by this contract via Permit2 with the given
    /// `deadline` & EIP712 `signature`.
    function approve2(address asset, uint256 amount, uint256 deadline, Signature calldata signature) external payable {
        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        ERC20Permit2(asset).simplePermit2(
            _initiator, address(this), amount, deadline, signature.v, signature.r, signature.s
        );
    }

    /// @dev Transfers the given `amount` of `asset` from sender to this contract via ERC20 transfer with Permit2
    /// fallback.
    function transferFrom2(address asset, uint256 amount) external payable {
        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        ERC20Permit2(asset).transferFrom2(_initiator, address(this), amount);
    }
}
