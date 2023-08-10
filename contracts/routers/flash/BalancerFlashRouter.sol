// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IBalancerFlashLender} from "./interfaces/IBalancerFlashLender.sol";
import {IBalancerFlashBorrower} from "./interfaces/IBalancerFlashBorrower.sol";

import {Errors} from "./libraries/Errors.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseFlashRouter} from "./BaseFlashRouter.sol";

abstract contract BalancerFlashRouter is BaseFlashRouter, IBalancerFlashBorrower {
    using SafeTransferLib for ERC20;

    /* IMMUTABLES */

    IBalancerFlashLender public immutable BALANCER_VAULT;

    /* CONSTRUCTOR */

    constructor(address balancerVault) {
        require(balancerVault != address(0), Errors.ZERO_ADDRESS);

        BALANCER_VAULT = IBalancerFlashLender(balancerVault);
    }

    /* EXTERNAL */

    function receiveFlashLoan(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        bytes calldata data
    ) external {
        _onCallback(data);

        for (uint256 i; i < assets.length; ++i) {
            ERC20(assets[i]).safeTransferFrom(_initiator, msg.sender, amounts[i] + fees[i]);
        }
    }

    /* ACTIONS */

    /// @dev Triggers a flash loan on Balancer.
    function balancerFlashLoan(address[] calldata assets, uint256[] calldata amounts, bytes calldata data) external {
        BALANCER_VAULT.flashLoan(address(this), assets, amounts, data);
    }
}
