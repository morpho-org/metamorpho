// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IWStEth} from "./interfaces/IWStEth.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "../BaseBulker.sol";

/// @title StEthBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
/// @notice Contract allowing to bundle multiple interactions with stETH together.
contract StEthBulker is BaseBulker {
    using SafeTransferLib for ERC20;

    /* CONSTANTS */

    /// @dev The address of the stETH contract.
    address internal constant _ST_ETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    /// @dev The address of the wstETH contract.
    address internal constant _WST_ETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    /* CONSTRUCTOR */

    constructor() {
        ERC20(_ST_ETH).safeApprove(_WST_ETH, type(uint256).max);
    }

    /* INTERNAL */

    /// @inheritdoc BaseBulker
    function _dispatch(Action memory action) internal virtual override returns (bool) {
        if (super._dispatch(action)) return true;

        if (action.actionType == ActionType.WRAP_ST_ETH) {
            _wrapStEth(action.data);
        } else if (action.actionType == ActionType.UNWRAP_ST_ETH) {
            _unwrapStEth(action.data);
        } else {
            return false;
        }

        return true;
    }

    /* PRIVATE */

    /// @dev Wraps the given input of stETH to wstETH.
    function _wrapStEth(bytes memory data) private {
        (uint256 amount) = abi.decode(data, (uint256));

        amount = Math.min(amount, ERC20(_ST_ETH).balanceOf(address(this)));
        if (amount == 0) revert AmountIsZero();

        IWStEth(_WST_ETH).wrap(amount);
    }

    /// @dev Unwraps the given input of wstETH to stETH.
    function _unwrapStEth(bytes memory data) private {
        (uint256 amount, address receiver) = abi.decode(data, (uint256, address));
        if (receiver == address(this)) revert AddressIsBulker();
        if (receiver == address(0)) revert AddressIsZero();

        amount = Math.min(amount, ERC20(_WST_ETH).balanceOf(address(this)));
        if (amount == 0) revert AmountIsZero();

        uint256 unwrapped = IWStEth(_WST_ETH).unwrap(amount);

        ERC20(_ST_ETH).safeTransfer(receiver, unwrapped);
    }
}
