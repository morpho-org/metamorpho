// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.2;

import {MarketAllocation} from "../interfaces/ISupplyVault.sol";

interface IVaultAllocationStrategy {
    function allocate(address caller, address owner, uint256 assets, uint256 shares)
        external
        view
        returns (MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied);
}
