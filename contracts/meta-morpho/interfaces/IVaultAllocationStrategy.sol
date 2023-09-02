// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.2;

import {MarketAllocation} from "../interfaces/ISupplyVault.sol";
import {MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";

interface IVaultAllocationStrategy {
    function allocate(address caller, address owner, uint256 assets, MarketParams[] calldata allMarketParams)
        external
        view
        returns (MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied);
}
