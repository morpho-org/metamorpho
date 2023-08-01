// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IFlashBorrower} from "@morpho-blue/interfaces/IFlashBorrower.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "./BaseBulker.sol";

abstract contract BlueFlashBulker is BaseBulker {
    using SafeTransferLib for ERC20;

    function onBlueFlashLoan(address, address asset, uint256 amount, bytes calldata data) external override {
        _checkInitiated();

        _decodeExecute(data);

        ERC20(asset).safeApprove(msg.sender, amount);
    }
}
