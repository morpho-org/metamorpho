// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AaveV2Bulker} from "../AaveV2Bulker.sol";
import {AaveV3Bulker} from "../AaveV3Bulker.sol";
import {BalancerBulker} from "../BalancerBulker.sol";

import {BlueBulker} from "../BlueBulker.sol";
import {ERC20Bulker} from "../ERC20Bulker.sol";
import {WNativeBulker} from "../WNativeBulker.sol";

contract PolygonBulker is ERC20Bulker, WNativeBulker, BlueBulker, AaveV2Bulker, AaveV3Bulker, BalancerBulker {
    constructor(address blue)
        WNativeBulker(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270)
        BlueBulker(blue)
        AaveV2Bulker(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf)
        AaveV3Bulker(0x794a61358D6845594F94dc1DB02A252b5b4814aD)
        BalancerBulker(0xBA12222222228d8Ba445958a75a0704d566BF2C8)
    {}
}
