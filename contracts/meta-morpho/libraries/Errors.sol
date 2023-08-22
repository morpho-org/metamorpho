// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";

error UnauthorizedMarket(MarketParams marketParams);

error InconsistentAsset(address asset);

error SupplyCapExceeded(uint256 supply);

library Errors {
    string internal constant UNINITIATED = "uninitiated";
}
