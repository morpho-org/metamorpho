// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IAaveFlashLender} from "./interfaces/IAaveFlashLender.sol";

import {BaseBulker} from "./BaseBulker.sol";
import {AaveBulker} from "./AaveBulker.sol";

contract AaveV2Bulker is BaseBulker, AaveBulker {
    /* IMMUTABLES */

    IAaveFlashLender internal immutable _AAVE_V2;

    /* CONSTRUCTOR */

    constructor(address aaveV2) {
        if (aaveV2 == address(0)) revert AddressIsZero();

        _AAVE_V2 = IAaveFlashLender(aaveV2);
    }
}
