// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20Bundler} from "../ERC20Bundler.sol";
import {MorphoBundler} from "../MorphoBundler.sol";
import {WNativeBundler} from "../WNativeBundler.sol";
import {StEthBundler} from "./StEthBundler.sol";

/// @title EthereumBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
contract EthereumBundler is ERC20Bundler, WNativeBundler, StEthBundler, MorphoBundler {
    /* CONSTANTS */

    /// @dev The address of the WETH contract on Ethreum mainnet.
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /* CONSTRUCTOR */

    constructor(address morpho) WNativeBundler(WETH) MorphoBundler(morpho) {}
}
