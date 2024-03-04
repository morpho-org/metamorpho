// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {Id, MarketParams, Market, IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

interface IMorphoHarness is IMorpho {
    function supplyShares(Id id, address user) external view returns (uint256);

    function borrowShares(Id id, address user) external view returns (uint256);

    function collateral(Id id, address user) external view returns (uint256);

    function totalSupplyAssets(Id id) external view returns (uint256);

    function totalSupplyShares(Id id) external view returns (uint256);

    function totalBorrowAssets(Id id) external view returns (uint256);

    function totalBorrowShares(Id id) external view returns (uint256);

    function lastUpdate(Id id) external view returns (uint256);

    function fee(Id id) external view returns (uint256);

    function expectedMarketBalances(MarketParams memory marketParams)
        external
        view
        returns (uint256, uint256, uint256, uint256);

    function expectedTotalSupplyAssets(MarketParams memory marketParams)
        external
        view
        returns (uint256 totalSupplyAssets);

    function expectedTotalBorrowAssets(MarketParams memory marketParams)
        external
        view
        returns (uint256 totalBorrowAssets);

    function expectedTotalSupplyShares(MarketParams memory marketParams)
        external
        view
        returns (uint256 totalSupplyShares);

    function expectedSupplyAssets(MarketParams memory marketParams, address user) external view returns (uint256);

    function expectedBorrowAssets(MarketParams memory marketParams, address user) external view returns (uint256);
}
