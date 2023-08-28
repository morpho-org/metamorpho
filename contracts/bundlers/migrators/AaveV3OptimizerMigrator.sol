// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MorphoBundler} from "../MorphoBundler.sol";
import {ERC4626Bundler} from "../ERC4626Bundler.sol";
import {AaveV3OptimizerBundler} from "../AaveV3OptimizerBundler.sol";

contract AaveV3OptimizerMigrator is MorphoBundler, ERC4626Bundler, AaveV3OptimizerBundler {
    constructor(address morpho, address aaveV3Optimizer)
        MorphoBundler(morpho)
        AaveV3OptimizerBundler(aaveV3Optimizer)
    {}
}
