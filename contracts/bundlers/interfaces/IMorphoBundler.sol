// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import {
    IMorphoRepayCallback,
    IMorphoSupplyCallback,
    IMorphoSupplyCollateralCallback,
    IMorphoFlashLoanCallback
} from "@morpho-blue/interfaces/IMorphoCallbacks.sol";

interface IMorphoBundler is
    IMorphoSupplyCallback,
    IMorphoRepayCallback,
    IMorphoSupplyCollateralCallback,
    IMorphoFlashLoanCallback
{}
