// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {MorphoBundler} from "./MorphoBundler.sol";
import {ERC20Bundler} from "./ERC20Bundler.sol";

/// @title EVMBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Common bundler layer guaranteeing it can be deployed to the same address on all EVM-compatible chains.
contract EVMBundler is ERC20Bundler, MorphoBundler {
    constructor(address morpho) MorphoBundler(morpho) {}
}
