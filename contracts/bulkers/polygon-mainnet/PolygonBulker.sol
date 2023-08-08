// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {BlueBulker} from "../BlueBulker.sol";
import {ERC20Bulker} from "../ERC20Bulker.sol";
import {WNativeBulker} from "../WNativeBulker.sol";

contract PolygonBulker is ERC20Bulker, WNativeBulker, BlueBulker {
    constructor(address blue) WNativeBulker(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270) BlueBulker(blue) {}
}
