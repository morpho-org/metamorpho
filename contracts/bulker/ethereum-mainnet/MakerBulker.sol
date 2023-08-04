// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IERC3156FlashLender} from "../interfaces/IERC3156FlashLender.sol";

import {BaseBulker} from "../BaseBulker.sol";
import {ERC3156Bulker} from "../ERC3156Bulker.sol";

contract MakerBulker is BaseBulker, ERC3156Bulker {
    /* IMMUTABLES */

    IERC3156FlashLender internal immutable _MAKER_VAULT;

    /* CONSTRUCTOR */

    constructor(address makerVault) {
        if (makerVault == address(0)) revert AddressIsZero();

        _MAKER_VAULT = IERC3156FlashLender(makerVault);
    }
}
