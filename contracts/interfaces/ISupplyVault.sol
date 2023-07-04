// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface ISupplyVault {
    /* STRUCTS */

    /* ERRORS */

    error OnlyRiskManager();

    error OnlyAllocationManager();

    error UnauthorizedCollateral(address collateral);
}
