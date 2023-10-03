// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing error messages.
library ErrorsLib {
    /// @notice Thrown when the address passed is the zero address.
    string internal constant ZERO_ADDRESS = "zero address";

    /// @notice Thrown when the caller is not the risk manager.
    string internal constant NOT_RISK_MANAGER = "not risk manager";

    /// @notice Thrown when the caller is not an allocator.
    string internal constant NOT_ALLOCATOR = "not allocator";

    /// @notice Thrown when the caller is not the guardian.
    string internal constant NOT_GUARDIAN = "not guardian";

    /// @notice Thrown when the market cannot be set in the supply queue.
    string internal constant UNAUTHORIZED_MARKET = "unauthorized market";

    /// @notice Thrown when submitting a cap for a market whose loan token does not correspond to `asset`.
    string internal constant INCONSISTENT_ASSET = "inconsistent asset";

    /// @notice Thrown when the supply cap has been exceeded on market during a reallocation of funds.
    string internal constant SUPPLY_CAP_EXCEEDED = "supply cap exceeded";

    /// @notice Thrown when the fee to set exceeds the maximum fee.
    string internal constant MAX_FEE_EXCEEDED = "max fee exceeded";

    /// @notice Thrown when the value is already set.
    string internal constant ALREADY_SET = "already set";

    /// @notice Thrown when there's no timelock.
    string internal constant NO_TIMELOCK = "no timelock";

    /// @notice Thrown when a market is a duplicate in the new withdraw queue to set.
    string internal constant DUPLICATE_MARKET = "duplicate market";

    /// @notice Thrown when a market is missing in the new withdraw queue to set.
    string internal constant MISSING_MARKET = "missing market";

    /// @notice Thrown when there's no pending value to set.
    string internal constant NO_PENDING_VALUE = "no pending value";

    /// @notice Thrown when the remaining asset to withdraw is not 0.
    string internal constant WITHDRAW_FAILED_MORPHO = "withdraw failed on Morpho";

    /// @notice Thrown when submitting a cap for a market which does not exist.
    string internal constant MARKET_NOT_CREATED = "market not created";

    /// @notice Thrown when the max timelock is exceeded.
    string internal constant MAX_TIMELOCK_EXCEEDED = "max timelock exceeded";

    /// @notice Thrown when the timelock is not elapsed.
    string internal constant TIMELOCK_NOT_ELAPSED = "timelock not elapsed";

    /// @notice Thrown when the timelock expiration is exceeded.
    string internal constant TIMELOCK_EXPIRATION_EXCEEDED = "timelock expiration exceeded";

    /// @notice Thrown when too many markets are in the withdraw queue.
    string internal constant MAX_QUEUE_SIZE_EXCEEDED = "max queue size exceeded";

    /// @notice Thrown when setting the fee to a non zero value while the fee recipient is the zero address.
    string internal constant ZERO_FEE_RECIPIENT = "fee recipient is zero";

    /// @notice Thrown when the idle liquidity is insufficient to cover supply during a reallocation of funds.
    string internal constant INSUFFICIENT_IDLE = "insufficient idle liquidity";
}
