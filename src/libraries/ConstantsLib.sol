// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @dev The delay after a timelock ends after which the owner must submit a parameter again.
/// It guarantees users that the owner only accepts parameters submitted recently.
uint256 constant TIMELOCK_EXPIRATION = 3 days;

/// @dev The maximum delay of a timelock.
uint256 constant MAX_TIMELOCK = 2 weeks;

/// @dev OpenZeppelin's decimals offset used in MetaMorpho's ERC4626 implementation.
uint8 constant DECIMALS_OFFSET = 6;

/// @dev The maximum supply/withdraw queue size ensuring the cost of depositing/withdrawing from the vault fits in a
/// block.
uint256 constant MAX_QUEUE_SIZE = 64;

/// @dev The maximum fee the vault can have (50%).
uint256 constant MAX_FEE = 0.5e18;
