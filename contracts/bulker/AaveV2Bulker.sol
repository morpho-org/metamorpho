// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IAaveFlashLender} from "./interfaces/IAaveFlashLender.sol";

import {Errors} from "./libraries/Errors.sol";

import {BaseBulker} from "./BaseBulker.sol";
import {AaveBulker} from "./AaveBulker.sol";

contract AaveV2Bulker is BaseBulker, AaveBulker {
    /* IMMUTABLES */

    IAaveFlashLender internal immutable _AAVE_V2;

    /* CONSTRUCTOR */

    constructor(address aaveV2) {
        require(aaveV2 != address(0), Errors.ZERO_ADDRESS);

        _AAVE_V2 = IAaveFlashLender(aaveV2);
    }

    /* ACTIONS */

    /// @dev Triggers a flash loan on AaveV2.
    function aaveV2FlashLoan(address[] calldata assets, uint256[] calldata amounts, bytes calldata data) external {
        _aaveFlashLoan(_AAVE_V2, assets, amounts, data);
    }
}
