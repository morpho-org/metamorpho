// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import {IPool} from "contracts/interfaces/IPool.sol";

interface ISupplyVault {
    /* STRUCTS */

    struct CollateralConfig {
        IPool pool;
        uint256 bucket;
        uint256 cap;
        bool enabled;
    }

    struct Config {
        address[] collaterals;
        mapping(address collateral => CollateralConfig config) collateralConfig;
    }

    /* ERRORS */

    error OnlyRiskManager();
}
