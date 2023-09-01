// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {ICompoundV3} from "./interfaces/ICompoundV3.sol";

import {MigrationBundler} from "./MigrationBundler.sol";
import {ERC20Bundler} from "../ERC20Bundler.sol";

contract CompoundV3MigrationBundler is MigrationBundler, ERC20Bundler {
    constructor(address morpho) MigrationBundler(morpho) {}

    function compoundV3Supply(address instance, address asset, uint256 amount) external {
        _approveMaxTo(asset, instance);
        ICompoundV3(instance).supplyTo(_initiator, asset, amount);
    }

    function compoundV3Withdraw(address instance, address asset, uint256 amount) external {
        ICompoundV3(instance).withdraw(asset, amount);
    }

    function compoundV3WithdrawFrom(address instance, address to, address asset, uint256 amount) external {
        ICompoundV3(instance).withdrawFrom(_initiator, to, asset, amount);
    }

    function compoundV3AllowBySig(
        address instance,
        bool isAllowed,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        ICompoundV3(instance).allowBySig(_initiator, address(this), isAllowed, nonce, expiry, v, r, s);
    }
}
