// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MakerBulker} from "./MakerBulker.sol";
import {AaveV2Bulker} from "../AaveV2Bulker.sol";
import {AaveV3Bulker} from "../AaveV3Bulker.sol";
import {BalancerBulker} from "../BalancerBulker.sol";

import {BlueBulker} from "../BlueBulker.sol";
import {ERC20Bulker} from "../ERC20Bulker.sol";
import {WNativeBulker} from "../WNativeBulker.sol";
import {StEthBulker} from "./StEthBulker.sol";

contract EthereumBulker is
    ERC20Bulker,
    WNativeBulker,
    StEthBulker,
    BlueBulker,
    AaveV2Bulker,
    AaveV3Bulker,
    BalancerBulker,
    MakerBulker
{
    constructor(address blue)
        WNativeBulker(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
        BlueBulker(blue)
        AaveV2Bulker(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9)
        AaveV3Bulker(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2)
        BalancerBulker(0xBA12222222228d8Ba445958a75a0704d566BF2C8)
        MakerBulker(0x60744434d6339a6B27d73d9Eda62b6F66a0a04FA)
    {}
}
