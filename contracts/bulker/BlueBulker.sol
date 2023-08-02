// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IBlueBulker} from "./interfaces/IBlueBulker.sol";

import {BaseBulker} from "./BaseBulker.sol";
import {AaveFlashBulker} from "./AaveFlashBulker.sol";
import {ERC3156FlashBulker} from "./ERC3156FlashBulker.sol";
import {BalancerFlashBulker} from "./BalancerFlashBulker.sol";

contract BlueBulker is BaseBulker, ERC3156FlashBulker, BalancerFlashBulker, AaveFlashBulker {
    constructor(address blue) BaseBulker(blue) {}
}
