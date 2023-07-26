// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IAaveFlashBorrower} from "contracts/interfaces/IAaveFlashBorrower.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "contracts/BaseBulker.sol";

abstract contract AaveFlashBulker is BaseBulker, IAaveFlashBorrower {
    using SafeTransferLib for ERC20;

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        address,
        bytes calldata data
    ) external payable override returns (bool) {
        _checkInitiated();

        _decodeExecute(data);

        for (uint256 i; i < assets.length; ++i) {
            ERC20(assets[i]).safeApprove(msg.sender, amounts[i] + fees[i]);
        }

        return true;
    }
}
