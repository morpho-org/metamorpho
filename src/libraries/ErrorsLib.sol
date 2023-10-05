// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id} from "@morpho-blue/interfaces/IMorpho.sol";

library ErrorsLib {
    error ZeroAddress();

    error NotRiskManager();

    error NotAllocator();

    error NotGuardian();

    error UnauthorizedMarket(Id id);

    error InconsistentAsset(Id id);

    error SupplyCapExceeded(Id id);

    /// @notice Thrown when the fee to set exceeds the maximum fee.
    error MaxFeeExceeded();

    /// @notice Thrown when the value is already set.
    error AlreadySet();

    error DuplicateMarket(Id id);

    error MissingMarket(Id id);

    error NoPendingValue();

    error WithdrawMorphoFailed();

    error MarketNotCreated();

    error MaxTimelockExceeded();

    error TimelockNotElapsed();

    error TimelockExpirationExceeded();

    error MaxQueueSizeExceeded();

    error ZeroFeeRecipient();

    error InsufficientIdle();
}
