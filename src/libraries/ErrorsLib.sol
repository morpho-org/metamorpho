// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id} from "@morpho-blue/interfaces/IMorpho.sol";

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing error messages.
library ErrorsLib {
    /// @notice Thrown when the address passed is the zero address.
    error ZeroAddress();

    /// @notice Thrown when the caller doesn't have the risk manager's privilege.
    error NotRiskManager();

    /// @notice Thrown when the caller doesn't have the allocator's privilege.
    error NotAllocator();

    /// @notice Thrown when the caller is not the guardian.
    error NotGuardian();

    /// @notice Thrown when the market `id` cannot be set in the supply queue.
    error UnauthorizedMarket(Id id);

    /// @notice Thrown when submitting a cap for a market `id` whose loan token does not correspond to the underlyin
    /// asset.
    error InconsistentAsset(Id id);

    /// @notice Thrown when the supply cap has been exceeded on market `id` during a reallocation of funds.
    error SupplyCapExceeded(Id id);

    /// @notice Thrown when the fee to set exceeds the maximum fee.
    error MaxFeeExceeded();

    /// @notice Thrown when the value is already set.
    error AlreadySet();

    /// @notice Thrown when market `id` is a duplicate in the new withdraw queue to set.
    error DuplicateMarket(Id id);

    /// @notice Thrown when market `id` is missing in the new withdraw queue to set.
    error MissingMarket(Id id);

    /// @notice Thrown when there's no pending value to set.
    error NoPendingValue();

    /// @notice Thrown when the remaining asset to withdraw is not 0.
    error WithdrawMorphoFailed();

    /// @notice Thrown when submitting a cap for a market which does not exist.
    error MarketNotCreated();

    /// @notice Thrown when the max timelock is exceeded.
    error MaxTimelockExceeded();

    /// @notice Thrown when the timelock is not elapsed.
    error TimelockNotElapsed();

    /// @notice Thrown when the timelock expiration is exceeded.
    error TimelockExpirationExceeded();

    /// @notice Thrown when too many markets are in the withdraw queue.
    error MaxQueueSizeExceeded();

    /// @notice Thrown when setting the fee to a non zero value while the fee recipient is the zero address.
    error ZeroFeeRecipient();

    /// @notice Thrown when the idle liquidity is insufficient to cover supply during a reallocation of funds.
    error InsufficientIdle();
}
