// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Id} from "@morpho-blue/interfaces/IMorpho.sol";
import {PendingUint192, PendingAddress} from "../interfaces/IMetaMorpho.sol";

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    /// @notice Emitted when a pending `newTimelock` is submitted.
    event SubmitTimelock(uint256 newTimelock);

    /// @notice Emitted `timelock` is set to `newTimelock`.
    event SetTimelock(address indexed caller, uint256 newTimelock);

    /// @notice Emitted `rewardsDistibutor` is set to `newRewardsRecipient`.
    event SetRewardsRecipient(address indexed newRewardsRecipient);

    /// @notice Emitted when a pending `newFee` is submitted.
    event SubmitFee(uint256 newFee);

    /// @notice Emitted `fee` is set to `newFee`.
    event SetFee(address indexed caller, uint256 newFee);

    /// @notice Emitted when a new `newFeeRecipient` is set.
    event SetFeeRecipient(address indexed newFeeRecipient);

    /// @notice Emitted when a pending `newGuardian` is submitted.
    event SubmitGuardian(address indexed newGuardian);

    /// @notice Emitted when `guardian` is set to `newGuardian`.
    event SetGuardian(address indexed caller, address indexed guardian);

    /// @notice Emitted when a pending `cap` is submitted for market identified by `id`.
    event SubmitCap(address indexed caller, Id indexed id, uint256 cap);

    /// @notice Emitted when a new `cap` is set for market identified by `id`.
    event SetCap(address indexed caller, Id indexed id, uint256 cap);

    /// @notice Emitted when the vault's last total assets is updated to `newTotalAssets`.
    event UpdateLastTotalAssets(uint256 newTotalAssets);

    /// @notice Emitted when `curator` is set to `newCurator`.
    event SetCurator(address indexed newCurator);

    /// @notice Emitted when an `allocator` is set to `isAllocator`.
    event SetIsAllocator(address indexed allocator, bool isAllocator);

    /// @notice Emitted when a `pendingTimelock` is revoked.
    event RevokePendingTimelock(address indexed caller);

    /// @notice Emitted when a `pendingCap` for the market identified by `id` is revoked.
    event RevokePendingCap(address indexed caller, Id indexed id);

    /// @notice Emitted when a `pendingGuardian` is revoked.
    event RevokePendingGuardian(address indexed caller);

    /// @notice Emitted when the `supplyQgueue` is set to `newSupplyQueue`.
    event SetSupplyQueue(address indexed caller, Id[] newSupplyQueue);

    /// @notice Emitted when the `withdrawQueue` is set to `newWithdrawQueue`.
    event SetWithdrawQueue(address indexed caller, Id[] newWithdrawQueue);

    /// @notice Emitted when a reallocation supplies assets to the market identified by `id`.
    /// @param id The id of the market.
    /// @param suppliedAssets The amount of assets supplied to the market.
    /// @param suppliedShares The amount of shares minted.
    event ReallocateSupply(address indexed caller, Id indexed id, uint256 suppliedAssets, uint256 suppliedShares);

    /// @notice Emitted when a reallocation withdraws assets from the market identified by `id`.
    /// @param id The id of the market.
    /// @param withdrawnAssets The amount of assets withdrawn from the market.
    /// @param withdrawnShares The amount of shares burned.
    event ReallocateWithdraw(address indexed caller, Id indexed id, uint256 withdrawnAssets, uint256 withdrawnShares);

    /// @notice Emitted when a reallocation added or removed assets from idle.
    event ReallocateIdle(address indexed caller, uint256 idle);

    /// @notice Emitted when fees are accrued.
    event AccrueFee(uint256 feeShares);

    /// @notice Emitted when an `amount` of `token` is transferred to the `rewardsRecipient` by `caller`.
    event TransferRewards(address indexed caller, address indexed token, uint256 amount);

    /// @notice Emitted when a new MetaMorpho vault is created.
    /// @param metaMorpho The address of the MetaMorpho vault.
    /// @param caller The caller of the function.
    /// @param initialOwner The initial owner of the MetaMorpho vault.
    /// @param initialTimelock The initial timelock of the MetaMorpho vault.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the MetaMorpho vault.
    /// @param symbol The symbol of the MetaMorpho vault.
    /// @param salt The salt used for the MetaMorpho vault's CREATE2 address.
    event CreateMetaMorpho(
        address indexed metaMorpho,
        address indexed caller,
        address initialOwner,
        uint256 initialTimelock,
        address indexed asset,
        string name,
        string symbol,
        bytes32 salt
    );
}
