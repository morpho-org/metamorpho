// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @dev The delay after a timelock ends after which the owner must submit a parameter again.
/// It guarantees users that the owner only accepts parameters submitted recently.
uint256 constant TIMELOCK_EXPIRATION = 3 days;

/// @dev The maximum delay of a timelock.
uint256 constant MAX_TIMELOCK = 2 weeks;

/// @dev OpenZeppelin's decimals offset used in MetaMorpho's ERC4626 implementation.
uint256 constant DECIMALS_OFFSET = 6;

/// @dev The role assigned to risk managers. Must be greater than the allocator role.
uint256 constant RISK_MANAGER_ROLE = 2;

/// @dev The role assigned to allocators.
uint256 constant ALLOCATOR_ROLE = 1;

/// @dev The maximum supply/withdraw queue size ensuring the cost of depositing/withdrawing from the vault fits in a
/// block.
uint256 constant MAX_QUEUE_SIZE = 64;
