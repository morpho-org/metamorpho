// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MorphoBundler} from "../MorphoBundler.sol";
import {ERC4626Bundler} from "../ERC4626Bundler.sol";
import {AaveV3Bundler} from "../AaveV3Bundler.sol";

contract AaveV3Migrator is MorphoBundler, ERC4626Bundler, AaveV3Bundler {
    constructor(address morpho, address aaveV3Pool) MorphoBundler(morpho) AaveV3Bundler(aaveV3Pool) {}
}
