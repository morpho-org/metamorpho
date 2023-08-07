// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import {
    IBlueRepayCallback,
    IBlueSupplyCallback,
    IBlueSupplyCollateralCallback,
    IBlueFlashLoanCallback
} from "@morpho-blue/interfaces/IBlueCallbacks.sol";

interface IBlueBulker is
    IBlueSupplyCallback,
    IBlueRepayCallback,
    IBlueSupplyCollateralCallback,
    IBlueFlashLoanCallback
{}
