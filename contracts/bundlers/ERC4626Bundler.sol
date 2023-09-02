// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {Math} from "@morpho-utils/math/Math.sol";
import {SafeTransferLib, ERC20} from "solmate/src/utils/SafeTransferLib.sol";

import {BaseBundler} from "./BaseBundler.sol";

/// @title ERC4626Bundler.
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Bundler contract managing interactions with ERC4626 compliant tokens.
abstract contract ERC4626Bundler is BaseBundler {
    using SafeTransferLib for ERC20;

    /* ACTIONS */

    function mint(address vault, uint256 shares, address receiver) external payable {
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);

        address asset = IERC4626(vault).asset();
        uint256 amount = Math.min(IERC4626(vault).maxDeposit(receiver), ERC20(asset).balanceOf(address(this)));

        shares = Math.min(shares, IERC4626(vault).previewDeposit(amount));
        amount = IERC4626(vault).previewMint(shares);

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        ERC20(asset).safeApprove(vault, amount);
        IERC4626(vault).mint(shares, receiver);
    }

    function deposit(address vault, uint256 amount, address receiver) external payable {
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);

        address asset = IERC4626(vault).asset();

        amount = Math.min(amount, IERC4626(vault).maxDeposit(receiver));
        amount = Math.min(amount, ERC20(asset).balanceOf(address(this)));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        ERC20(asset).safeApprove(vault, amount);
        IERC4626(vault).deposit(amount, receiver);
    }

    function withdraw(address vault, uint256 amount, address receiver) external payable {
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);

        address initiator = _initiator;
        amount = Math.min(amount, IERC4626(vault).maxWithdraw(initiator));

        require(amount != 0, ErrorsLib.ZERO_AMOUNT);

        IERC4626(vault).withdraw(amount, receiver, initiator);
    }

    function redeem(address vault, uint256 shares, address receiver) external payable {
        require(receiver != address(0), ErrorsLib.ZERO_ADDRESS);

        address initiator = _initiator;
        shares = Math.min(shares, IERC4626(vault).maxRedeem(initiator));

        require(shares != 0, ErrorsLib.ZERO_SHARES);

        IERC4626(vault).redeem(shares, receiver, initiator);
    }
}
