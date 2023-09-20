// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library ErrorsLib {
    string internal constant NOT_RISK_MANAGER = "not risk manager";

    string internal constant NOT_ALLOCATOR = "not allocator";

    string internal constant NOT_GUARDIAN = "not guardian";

    string internal constant UNAUTHORIZED_MARKET = "unauthorized market";

    string internal constant INCONSISTENT_ASSET = "inconsistent asset";

    string internal constant SUPPLY_CAP_EXCEEDED = "supply cap exceeded";

    /// @notice Thrown when the fee to set exceeds the maximum fee.
    string internal constant MAX_FEE_EXCEEDED = "max fee exceeded";

    /// @notice Thrown when the value is already set.
    string internal constant ALREADY_SET = "already set";

    string internal constant DUPLICATE_MARKET = "duplicate market";

    string internal constant MISSING_MARKET = "missing market";

    string internal constant WITHDRAW_FAILED_MORPHO = "withdraw failed on Morpho";

    string internal constant MARKET_NOT_CREATED = "market not created";

    string internal constant MAX_TIMELOCK_EXCEEDED = "max timelock exceeded";

    string internal constant TIMELOCK_NOT_ELAPSED = "timelock not elapsed";

    string internal constant TIMELOCK_EXPIRATION_EXCEEDED = "timelock expiration exceeded";

    string internal constant MAX_QUEUE_SIZE_EXCEEDED = "max queue size exceeded";
}
