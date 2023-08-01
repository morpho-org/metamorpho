// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "./BaseBulker.sol";

abstract contract ERC3156FlashBulker is BaseBulker {
    using SafeTransferLib for ERC20;

    bytes32 private constant FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

    function onFlashLoan(address, address asset, uint256 amount, uint256 fee, bytes calldata data)
        external
        payable
        override
        returns (bytes32)
    {
        _checkInitiated();

        _decodeExecute(data);

        ERC20(asset).safeApprove(msg.sender, amount + fee);

        return FLASHLOAN_CALLBACK;
    }
}
