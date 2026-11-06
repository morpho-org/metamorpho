// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id} from "../../../interfaces/IMetaMorpho.sol";

/// @title ErrorsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing error messages.
library ErrorsLib {
    /// @notice Thrown when the `msg.sender` is not the admin nor the owner of the vault.
    error NotAdminNorVaultOwner();

    /// @notice Thrown when the reallocation fee given is wrong.
    error IncorrectFee();

    /// @notice Thrown when the value is already set.
    error AlreadySet();

    /// @notice Thrown when `withdrawals` is empty.
    error EmptyWithdrawals();

    /// @notice Thrown when `withdrawals` contains a duplicate or is not sorted.
    error InconsistentWithdrawals();

    /// @notice Thrown when the deposit market is in `withdrawals`.
    error DepositMarketInWithdrawals();

    /// @notice Thrown when attempting to reallocate or set flows to non-zero values for a non-enabled market.
    error MarketNotEnabled(Id id);

    /// @notice Thrown when attempting to withdraw zero of a market.
    error WithdrawZero(Id id);

    /// @notice Thrown when attempting to set max inflow/outflow above the MAX_SETTABLE_FLOW_CAP.
    error MaxSettableFlowCapExceeded();

    /// @notice Thrown when attempting to withdraw more than the available supply of a market.
    error NotEnoughSupply(Id id);

    /// @notice Thrown when attempting to withdraw more than the max outflow of a market.
    error MaxOutflowExceeded(Id id);

    /// @notice Thrown when attempting to supply more than the max inflow of a market.
    error MaxInflowExceeded(Id id);
}
