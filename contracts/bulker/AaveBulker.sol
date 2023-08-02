// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IAaveFlashLender} from "./interfaces/IAaveFlashLender.sol";
import {IAaveFlashBorrower} from "./interfaces/IAaveFlashBorrower.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "./BaseBulker.sol";

abstract contract AaveBulker is BaseBulker, IAaveFlashBorrower {
    using SafeTransferLib for ERC20;

    /* EXTERNAL */

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        address,
        bytes calldata data
    ) external callback(data) returns (bool) {
        for (uint256 i; i < assets.length; ++i) {
            ERC20(assets[i]).safeApprove(msg.sender, amounts[i] + fees[i]);
        }

        return true;
    }

    /* INTERNAL */

    /// @dev Triggers a flash loan on Aave.
    function _aaveFlashLoan(IAaveFlashLender aave, bytes memory data) internal {
        (address[] memory assets, uint256[] memory amounts, bytes memory callbackData) =
            abi.decode(data, (address[], uint256[], bytes));

        aave.flashLoan(address(this), assets, amounts, new uint256[](assets.length), address(this), callbackData, 0);
    }
}
