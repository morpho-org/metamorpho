// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IIrm} from "../../lib/morpho-blue/src/interfaces/IIrm.sol";
import {MarketParams, Market} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

import {MathLib} from "../../lib/morpho-blue/src/libraries/MathLib.sol";

contract IrmMock is IIrm {
    using MathLib for uint128;

    uint256 public apr;

    function setApr(uint256 newApr) external {
        apr = newApr;
    }

    function borrowRateView(MarketParams memory, Market memory) public view returns (uint256) {
        return apr / 365 days;
    }

    function borrowRate(MarketParams memory marketParams, Market memory market) external view returns (uint256) {
        return borrowRateView(marketParams, market);
    }
}
