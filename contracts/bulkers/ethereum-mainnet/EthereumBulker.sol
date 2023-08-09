// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {BlueBulker} from "../BlueBulker.sol";
import {ERC20Bulker} from "../ERC20Bulker.sol";
import {WNativeBulker} from "../WNativeBulker.sol";
import {StEthBulker} from "./StEthBulker.sol";

/// @title EthereumBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
contract EthereumBulker is ERC20Bulker, WNativeBulker, StEthBulker, BlueBulker {
    address internal constant _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(address blue) WNativeBulker(_WETH) BlueBulker(blue) {}
}
