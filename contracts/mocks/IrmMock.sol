// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IIrm} from "@morpho-blue/interfaces/IIrm.sol";
import {MarketParams, Market} from "@morpho-blue/interfaces/IMorpho.sol";

import {MathLib} from "@morpho-blue/libraries/MathLib.sol";

contract IrmMock is IIrm {
    using MathLib for uint128;

    uint256 public apr;

    function setApr(uint256 newApr) external {
        apr = newApr;
    }

    function borrowRateView(MarketParams memory, Market memory market) public view returns (uint256) {
        uint256 utilization = market.totalBorrowAssets.wDivDown(market.totalSupplyAssets);

        // When apr is zero, x% utilization corresponds to x% APR.
        return apr == 0 ? utilization / 365 days : apr / 365 days;
    }

    function borrowRate(MarketParams memory marketParams, Market memory market) external view returns (uint256) {
        return borrowRateView(marketParams, market);
    }
}
