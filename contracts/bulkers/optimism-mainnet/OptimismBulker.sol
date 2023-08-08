// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {BlueBulker} from "../BlueBulker.sol";
import {ERC20Bulker} from "../ERC20Bulker.sol";
import {WNativeBulker} from "../WNativeBulker.sol";

contract OptimismBulker is ERC20Bulker, WNativeBulker, BlueBulker {
    constructor(address blue) WNativeBulker(0x4200000000000000000000000000000000000006) BlueBulker(blue) {}
}
