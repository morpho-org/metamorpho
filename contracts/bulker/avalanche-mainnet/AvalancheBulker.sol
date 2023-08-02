// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AaveV2Bulker} from "../AaveV2Bulker.sol";
import {AaveV3Bulker} from "../AaveV3Bulker.sol";
import {BalancerBulker} from "../BalancerBulker.sol";

import {BlueBulker} from "../BlueBulker.sol";
import {ERC20Bulker} from "../ERC20Bulker.sol";
import {WNativeBulker} from "../WNativeBulker.sol";

contract AvalancheBulker is ERC20Bulker, WNativeBulker, BlueBulker, AaveV2Bulker, AaveV3Bulker, BalancerBulker {
    constructor(address blue)
        WNativeBulker(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7)
        BlueBulker(blue)
        AaveV2Bulker(0x4F01AeD16D97E3aB5ab2B501154DC9bb0F1A5A2C)
        AaveV3Bulker(0x794a61358D6845594F94dc1DB02A252b5b4814aD)
        BalancerBulker(0xBA12222222228d8Ba445958a75a0704d566BF2C8)
    {}

    function _dispatch(Action memory action)
        internal
        override(ERC20Bulker, WNativeBulker, BlueBulker, AaveV2Bulker, AaveV3Bulker, BalancerBulker)
        returns (bool)
    {
        return super._dispatch(action);
    }
}
