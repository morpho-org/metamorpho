// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IAaveFlashLender} from "./interfaces/IAaveFlashLender.sol";

import {BaseBulker} from "./BaseBulker.sol";
import {AaveBulker} from "./AaveBulker.sol";

contract AaveV3Bulker is BaseBulker, AaveBulker {
    /* IMMUTABLES */

    IAaveFlashLender internal immutable _AAVE_V3;

    /* CONSTRUCTOR */

    constructor(address aaveV3) {
        if (aaveV3 == address(0)) revert AddressIsZero();

        _AAVE_V3 = IAaveFlashLender(aaveV3);
    }

    /* INTERNAL */

    /// @inheritdoc BaseBulker
    function _dispatch(Action memory action) internal virtual override returns (bool) {
        if (super._dispatch(action)) return true;

        if (action.actionType == ActionType.AAVE_V3_FLASH_LOAN) {
            _aaveFlashLoan(_AAVE_V3, action.data);
        } else {
            return false;
        }

        return true;
    }
}
