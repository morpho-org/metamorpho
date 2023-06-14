// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import {IPool} from "contracts/interfaces/IPool.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface ISupplyVault {
    /* STRUCTS */

    struct CollateralConfig {
        uint256 bucket;
        uint256 cap;
    }

    struct Config {
        EnumerableSet.AddressSet collaterals;
        mapping(address collateral => CollateralConfig config) collateralConfig;
    }

    /* ERRORS */

    error OnlyRiskManager();

    error OnlyAllocationManager();
}
