// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.2;

import {MarketParams, Id} from "@morpho-blue/interfaces/IMorpho.sol";

interface IMorphoMarketParams {
    function idToMarketParams(Id id) external returns (MarketParams memory marketParams);
}
