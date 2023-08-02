// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IBalancerFlashLender} from "./interfaces/IBalancerFlashLender.sol";
import {IBalancerFlashBorrower} from "./interfaces/IBalancerFlashBorrower.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "./BaseBulker.sol";

contract BalancerBulker is BaseBulker, IBalancerFlashBorrower {
    using SafeTransferLib for ERC20;

    /* IMMUTABLES */

    IBalancerFlashLender internal immutable _BALANCER_VAULT;

    /* CONSTRUCTOR */

    constructor(address aaveV2) {
        if (aaveV2 == address(0)) revert AddressIsZero();

        _BALANCER_VAULT = IBalancerFlashLender(aaveV2);
    }

    /* EXTERNAL */

    function receiveFlashLoan(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        bytes calldata data
    ) external callback(data) {
        for (uint256 i; i < assets.length; ++i) {
            ERC20(assets[i]).safeTransfer(msg.sender, amounts[i] + fees[i]);
        }
    }

    /* INTERNAL */

    /// @inheritdoc BaseBulker
    function _dispatch(Action memory action) internal virtual override returns (bool) {
        if (super._dispatch(action)) return true;

        if (action.actionType == ActionType.BALANCER_FLASH_LOAN) {
            _balancerFlashLoan(action.data);
        } else {
            return false;
        }

        return true;
    }

    /* PRIVATE */

    /// @dev Triggers a flash loan on Balancer.
    function _balancerFlashLoan(bytes memory data) private {
        (address[] memory assets, uint256[] memory amounts, bytes memory callbackData) =
            abi.decode(data, (address[], uint256[], bytes));

        _BALANCER_VAULT.flashLoan(address(this), assets, amounts, callbackData);
    }
}
