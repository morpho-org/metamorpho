// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id} from "@morpho-blue/interfaces/IMorpho.sol";
import {PendingUint192, PendingAddress} from "../interfaces/IMetaMorpho.sol";

library EventsLib {
    event SubmitTimelock(uint256 timelock);

    event SetTimelock(uint256 timelock);

    event SetRewardsDistributor(address indexed rewardsDistributor);

    event SubmitFee(uint256 fee);

    /// @notice Emitted when setting a new fee.
    /// @param fee The new fee.
    event SetFee(uint256 fee);

    /// @notice Emitted when setting a new fee recipient.
    /// @param feeRecipient The new fee recipient.
    event SetFeeRecipient(address indexed feeRecipient);

    event SubmitGuardian(address indexed guardian);

    /// @notice Emitted when setting a new guardian.
    /// @param guardian The new guardian.
    event SetGuardian(address indexed guardian);

    event SubmitCap(Id indexed id, uint256 cap);

    event SetCap(Id indexed id, uint256 cap);

    /// @notice Emitted when the vault's last total assets is updated.
    /// @param totalAssets The total amount of assets this vault manages.
    event UpdateLastTotalAssets(uint256 totalAssets);

    event SetRiskManager(address indexed riskManager);

    event SetIsAllocator(address indexed allocator, bool isAllocator);

    event RevokeTimelock(address indexed guardian, PendingUint192 pendingTimelock);

    event RevokeFee(address indexed guardian, PendingUint192 pendingFee);

    event RevokeCap(address indexed guardian, Id indexed id, PendingUint192 pendingCap);

    event RevokeGuardian(address indexed guardian, PendingAddress pendingGuardian);

    event SetSupplyQueue(address indexed allocator, Id[] id);

    event SetWithdrawQueue(address indexed allocator, Id[] id);

    event TransferRewards(
        address indexed caller, address indexed rewardsDistributor, address indexed token, uint256 amount
    );
}
