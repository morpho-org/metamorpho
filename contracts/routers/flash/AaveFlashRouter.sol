// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IAaveFlashLender} from "./interfaces/IAaveFlashLender.sol";
import {IAaveFlashBorrower} from "./interfaces/IAaveFlashBorrower.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseFlashRouter} from "./BaseFlashRouter.sol";

abstract contract AaveFlashRouter is BaseFlashRouter, IAaveFlashBorrower {
    using SafeTransferLib for ERC20;

    /* EXTERNAL */

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        address,
        bytes calldata data
    ) external returns (bool) {
        bytes[] memory calls = abi.decode(data, (bytes[]));

        _onCallback(calls);

        for (uint256 i; i < assets.length; ++i) {
            ERC20(assets[i]).safeTransferFrom(_initiator, address(this), amounts[i] + fees[i]);
        }

        return true;
    }

    /* INTERNAL */

    /// @dev Triggers a flash loan on Aave.
    function _aaveFlashLoan(
        IAaveFlashLender aave,
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata data
    ) internal {
        for (uint256 i; i < assets.length; ++i) {
            _approveMax(assets[i], address(aave));
        }

        aave.flashLoan(address(this), assets, amounts, new uint256[](assets.length), address(this), data, 0);
    }
}
