// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id} from "@morpho-blue/interfaces/IMorpho.sol";

library EventsLib {
    event SetRole(address indexed target, uint256 role);

    event SubmitTimelock(uint256 timelock);

    event SetTimelock(uint256 timelock);

    event SubmitFee(uint256 fee);

    /// @notice Emitted when setting a new fee.
    /// @param fee The new fee.
    event SetFee(uint256 fee);

    /// @notice Emitted when setting a new fee recipient.
    /// @param feeRecipient The new fee recipient.
    event SetFeeRecipient(address indexed feeRecipient);

    event SubmitRevocator(address indexed revocator);

    /// @notice Emitted when setting a new revocator.
    /// @param revocator The new revocator.
    event SetRevocator(address indexed revocator);

    event SubmitCap(address indexed riskManager, Id indexed id, uint256 cap);

    event SetCap(address indexed riskManager, Id indexed id, uint256 cap);

    /// @notice Emitted when the vault's last total assets is updated.
    /// @param totalAssets The total amount of assets this vault manages.
    event UpdateLastTotalAssets(uint256 totalAssets);

    event RevokeTimelock(address indexed revocator, uint256 pendingTimelock, uint256 submittedAt);

    event RevokeFee(address indexed revocator, uint256 pendingFee, uint256 submittedAt);

    event RevokeCap(address indexed revocator, Id indexed id, uint256 pendingCap, uint256 submittedAt);

    event RevokeRevocator(address indexed revocator, address pendingRevocator, uint256 submittedAt);
}
