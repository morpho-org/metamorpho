// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Market} from "@morpho-blue/interfaces/IMorpho.sol";

error UnauthorizedMarket(Market market);

error InconsistentAsset(address asset);

error SupplyCapExceeded(uint256 supply);

library Errors {
    string internal constant UNINITIATED = "uninitiated";
}
