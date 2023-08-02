// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IERC3156FlashLender} from "./interfaces/IERC3156FlashLender.sol";

import {BaseBulker} from "./BaseBulker.sol";
import {ERC3156Bulker} from "./ERC3156Bulker.sol";

contract MakerBulker is BaseBulker, ERC3156Bulker {
    /* IMMUTABLES */

    IERC3156FlashLender internal immutable _MAKER_VAULT;

    /* CONSTRUCTOR */

    constructor(address makerVault) {
        if (makerVault == address(0)) revert AddressIsZero();

        _MAKER_VAULT = IERC3156FlashLender(makerVault);
    }

    /* INTERNAL */

    /// @inheritdoc BaseBulker
    function _dispatch(Action memory action) internal virtual override returns (bool) {
        if (super._dispatch(action)) return true;

        if (action.actionType == ActionType.MAKER_FLASH_LOAN) {
            _erc3156FlashLoan(_MAKER_VAULT, action.data);
        } else {
            return false;
        }

        return true;
    }
}
