// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../lib/morpho-blue/src/libraries/MarketParamsLib.sol";

contract MorphoHavoc {
    using MarketParamsLib for MarketParams;

    function havocDummy() external pure {}

    function libId(MarketParams memory marketParams) external pure returns (Id) {
        return marketParams.id();
    }
}
