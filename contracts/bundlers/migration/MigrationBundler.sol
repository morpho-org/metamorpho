// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MorphoBundler} from "../MorphoBundler.sol";
import {ERC4626Bundler} from "../ERC4626Bundler.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

abstract contract MigrationBundler is MorphoBundler, ERC4626Bundler {
    using SafeTransferLib for ERC20;

    constructor(address morpho) MorphoBundler(morpho) {}

    function _approveMaxTo(address asset, address to) internal {
        if (ERC20(asset).allowance(address(this), to) == 0) {
            ERC20(asset).safeApprove(to, type(uint256).max);
        }
    }
}
