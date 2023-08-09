// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {BaseBulker} from "../BaseBulker.sol";
import {BlueBulker} from "../BlueBulker.sol";
import {ERC20Bulker} from "../ERC20Bulker.sol";
import {WNativeBulker} from "../WNativeBulker.sol";
import {StEthBulker} from "./StEthBulker.sol";

contract EthereumBulker is ERC20Bulker, WNativeBulker, StEthBulker, BlueBulker {
    constructor(address blue) WNativeBulker(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) BlueBulker(blue) {}
}
