// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {MarketParams, Id} from "@morpho-blue/interfaces/IMorpho.sol";

interface IMorphoMarketParams {
    function idToMarketParams(Id id) external view returns (MarketParams memory marketParams);
}
