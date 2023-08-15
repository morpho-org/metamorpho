// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {ERC4626Bulker} from "../ERC4626Bulker.sol";
import {WNativeBulker} from "../WNativeBulker.sol";
import {StEthBulker} from "./StEthBulker.sol";

/// @title EthereumWrapperBulker
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
contract EthereumWrapperBulker is ERC4626Bulker, WNativeBulker, StEthBulker {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor() WNativeBulker(WETH) {}
}
