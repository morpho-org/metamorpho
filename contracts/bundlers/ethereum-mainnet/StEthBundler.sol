// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IWStEth} from "./interfaces/IWStEth.sol";

import {Errors} from "../libraries/Errors.sol";
import {Math} from "@morpho-utils/math/Math.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBundler} from "../BaseBundler.sol";

/// @title StEthBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Contract allowing to bundle multiple interactions with stETH together.
abstract contract StEthBundler is BaseBundler {
    using SafeTransferLib for ERC20;

    /* CONSTANTS */

    /// @dev The address of the stETH contract.
    address public constant ST_ETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    /// @dev The address of the wstETH contract.
    address public constant WST_ETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    /* CONSTRUCTOR */

    constructor() {
        ERC20(ST_ETH).safeApprove(WST_ETH, type(uint256).max);
    }

    /* ACTIONS */

    /// @dev Wraps the given `amount` of stETH to wstETH.
    function wrapStEth(uint256 amount, address receiver) external {
        amount = Math.min(amount, ERC20(ST_ETH).balanceOf(address(this)));

        require(amount != 0, Errors.ZERO_AMOUNT);

        amount = IWStEth(WST_ETH).wrap(amount);

        if (receiver != address(this)) ERC20(ST_ETH).safeTransfer(receiver, amount);
    }

    /// @dev Unwraps the given `amount` of wstETH to stETH.
    function unwrapStEth(uint256 amount, address receiver) external {
        require(receiver != address(this), Errors.BUNDLER_ADDRESS);
        require(receiver != address(0), Errors.ZERO_ADDRESS);

        amount = Math.min(amount, ERC20(WST_ETH).balanceOf(address(this)));

        require(amount != 0, Errors.ZERO_AMOUNT);

        uint256 unwrapped = IWStEth(WST_ETH).unwrap(amount);

        ERC20(ST_ETH).safeTransfer(receiver, unwrapped);
    }
}
