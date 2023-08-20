// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import {IOracle as IBlueOracle} from "@morpho-blue/interfaces/IOracle.sol";

import {ICollateralAdapter} from "../adapters/interfaces/ICollateralAdapter.sol";
import {IBorrowableAdapter} from "../adapters/interfaces/IBorrowableAdapter.sol";

interface IOracle is IBlueOracle, ICollateralAdapter, IBorrowableAdapter {}
