// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MarketKey} from "@morpho-blue/libraries/Types.sol";

error UnauthorizedMarket(MarketKey marketKey);

error InconsistentAsset(address asset);

error SupplyOverCap(uint256 supply);
