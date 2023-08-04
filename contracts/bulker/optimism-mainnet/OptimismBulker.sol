// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AaveV3Bulker} from "../AaveV3Bulker.sol";
import {BalancerBulker} from "../BalancerBulker.sol";

import {BlueBulker} from "../BlueBulker.sol";
import {ERC20Bulker} from "../ERC20Bulker.sol";
import {WNativeBulker} from "../WNativeBulker.sol";

contract OptimismBulker is ERC20Bulker, WNativeBulker, BlueBulker, AaveV3Bulker, BalancerBulker {
    constructor(address blue)
        WNativeBulker(0x4200000000000000000000000000000000000006)
        BlueBulker(blue)
        AaveV3Bulker(0x794a61358D6845594F94dc1DB02A252b5b4814aD)
        BalancerBulker(0xBA12222222228d8Ba445958a75a0704d566BF2C8)
    {}
}
