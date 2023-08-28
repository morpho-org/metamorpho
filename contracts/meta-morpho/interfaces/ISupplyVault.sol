// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface ISupplyVault {
    /* STRUCTS */

    /* ERRORS */

    error OnlyRiskManager();

    error OnlyAllocationManager();

    error UnauthorizedCollateral(address collateral);
}
