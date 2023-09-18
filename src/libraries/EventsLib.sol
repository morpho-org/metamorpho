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
    /// @param fee The new fee.
    event SetFee(uint256 fee);

    /// @notice Emitted when setting a new fee recipient.
    /// @param feeRecipient The new fee recipient.
    event SetFeeRecipient(address indexed feeRecipient);

    event SubmitCap(Id id, uint256 cap);

    event SetCap(Id id, uint256 cap);

    /// @notice Emitted when the vault's last total assets is updated.
    /// @param totalAssets The total amount of assets this vault manages.
    event UpdateLastTotalAssets(uint256 totalAssets);
}
