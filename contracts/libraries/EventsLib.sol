// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id} from "@morpho-blue/interfaces/IMorpho.sol";

library EventsLib {
    event SubmitTimelock(uint256 timelock);

    event AcceptTimelock(uint256 timelock);

    event SetIsRiskManager(address indexed riskManager, bool isRiskManager);

    event SetIsAllocator(address indexed allocator, bool isAllocator);

    event SubmitFee(uint256 fee);

    /// @notice Emitted when setting a new fee.
    /// @param newFee The new fee.
    event AcceptFee(uint256 newFee);

    /// @notice Emitted when setting a new fee recipient.
    /// @param newFeeRecipient The new fee recipient.
    event SetFeeRecipient(address indexed newFeeRecipient);

    event SubmitMarket(Id id);

    event EnableMarket(Id id, uint128 cap);

    event SetCap(uint128 cap);

    event DisableMarket(Id id);

    /// @notice Emitted when the vault's performance fee is accrued.
    /// @param totalAssets The total amount of assets this vault manages.
    /// @param feeShares The shares minted corresponding to the fee accrued.
    event AccrueFee(uint256 totalAssets, uint256 feeShares);
}
