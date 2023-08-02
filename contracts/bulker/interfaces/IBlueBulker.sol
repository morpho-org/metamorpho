// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import {
    IBlueRepayCallback,
    IBlueSupplyCallback,
    IBlueSupplyCollateralCallback
} from "@morpho-blue/interfaces/IBlueCallbacks.sol";
import {IFlashBorrower} from "@morpho-blue/interfaces/IFlashBorrower.sol";
import {IBaseBulker} from "./IBaseBulker.sol";

interface IBlueBulker is
    IBaseBulker,
    IFlashBorrower,
    IBlueSupplyCallback,
    IBlueRepayCallback,
    IBlueSupplyCollateralCallback
{}
