// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "./BaseBulker.sol";

abstract contract BalancerFlashBulker is BaseBulker {
    using SafeTransferLib for ERC20;

    function receiveFlashLoan(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        bytes calldata data
    ) external payable override {
        _checkInitiated();

        _decodeExecute(data);

        for (uint256 i; i < assets.length; ++i) {
            ERC20(assets[i]).safeTransfer(msg.sender, amounts[i] + fees[i]);
        }
    }
}
