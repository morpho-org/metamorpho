// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library EventsLib {
    event SetIsRiskManager(address indexed riskManager, bool isRiskManager);

    event SetIsAllocator(address indexed allocator, bool isAllocator);

    event SetSupplyStrategy(address indexed supplyStrategy);

    event SetWithdrawStrategy(address indexed withdrawStrategy);

    /// @notice Emitted when setting a new fee.
    /// @param newFee The new fee.
    event SetFee(uint256 newFee);

    /// @notice Emitted when setting a new fee recipient.
    /// @param newFeeRecipient The new fee recipient.
    event SetFeeRecipient(address indexed newFeeRecipient);

    /// @notice Emitted when the vault's performance fee is accrued.
    /// @param totalAssets The total amount of assets this vault manages.
    /// @param feeShares The shares minted corresponding to the fee accrued.
    event AccrueFee(uint256 totalAssets, uint256 feeShares);
}
