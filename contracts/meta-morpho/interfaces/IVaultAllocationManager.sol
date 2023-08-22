// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import {MarketAllocation} from "../libraries/Types.sol";

interface IVaultAllocationManager {
    function allocateSupply(address caller, address receiver, uint256 assets, uint256 shares)
        external
        view
        returns (MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied);

    function allocateWithdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        external
        view
        returns (MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied);
}
