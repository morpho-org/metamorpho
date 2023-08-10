// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {Errors} from "./libraries/Errors.sol";
import {Math} from "@morpho-utils/math/Math.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "./BaseBulker.sol";

/// @title ERC4626Bulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
abstract contract ERC4626Bulker is BaseBulker {
    using SafeTransferLib for ERC20;

    /* ACTIONS */

    function mint(address vault, uint256 shares, address receiver) external {
        require(receiver != address(0), Errors.ZERO_ADDRESS);
        require(receiver != address(this), Errors.BULKER_ADDRESS);

        shares = Math.min(shares, IERC4626(vault).maxMint(receiver));

        address asset = IERC4626(vault).asset();
        uint256 amount = Math.min(IERC4626(vault).previewMint(shares), ERC20(asset).balanceOf(address(this)));

        require(amount != 0, Errors.ZERO_AMOUNT);

        ERC20(asset).safeApprove(vault, amount);
        IERC4626(vault).mint(shares, receiver);
    }

    function deposit(address vault, uint256 amount, address receiver) external {
        require(receiver != address(0), Errors.ZERO_ADDRESS);
        require(receiver != address(this), Errors.BULKER_ADDRESS);

        address asset = IERC4626(vault).asset();
        amount = Math.min(Math.min(amount, IERC4626(vault).maxDeposit(receiver)), ERC20(asset).balanceOf(address(this)));

        require(amount != 0, Errors.ZERO_AMOUNT);

        ERC20(asset).safeApprove(vault, amount);
        IERC4626(vault).deposit(amount, receiver);
    }

    function withdraw(address vault, uint256 amount, address receiver) external {
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        amount = Math.min(amount, IERC4626(vault).maxWithdraw(msg.sender));

        require(amount != 0, Errors.ZERO_AMOUNT);

        IERC4626(vault).withdraw(amount, receiver, msg.sender);
    }

    function redeem(address vault, uint256 shares, address receiver) external {
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        shares = Math.min(shares, IERC4626(vault).maxRedeem(msg.sender));

        uint256 amount = IERC4626(vault).previewRedeem(shares);

        require(amount != 0, Errors.ZERO_AMOUNT);

        IERC4626(vault).redeem(shares, receiver, msg.sender);
    }
}
