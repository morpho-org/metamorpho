// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {WNativeBulker} from "../WNativeBulker.sol";
import {StEthBulker} from "./StEthBulker.sol";

/// @title EthereumBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
contract EthereumBulker is WNativeBulker, StEthBulker {
    address private constant _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor() WNativeBulker(_WETH) {}
}
