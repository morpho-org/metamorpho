// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {BaseBulker} from "../BaseBulker.sol";
import {BlueBulker} from "../BlueBulker.sol";
import {ERC20Bulker} from "../ERC20Bulker.sol";
import {WNativeBulker} from "../WNativeBulker.sol";
import {OneInchBulker} from "../OneInchBulker.sol";
import {StEthBulker} from "./StEthBulker.sol";

contract EthereumBulker is BaseBulker, ERC20Bulker, WNativeBulker, StEthBulker, OneInchBulker, BlueBulker {
    constructor(address blue)
        WNativeBulker(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
        OneInchBulker(0x1111111254EEB25477B68fb85Ed929f73A960582)
        BlueBulker(blue)
    {}
}
