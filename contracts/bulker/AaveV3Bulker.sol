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
}
