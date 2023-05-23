// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {BytesLib} from "src/libraries/BytesLib.sol";

/// @dev The length of the bytes encoded address.
uint256 constant ADDR_LENGTH = 20;

/// @dev The length of the bytes encoded maxLtv.
uint256 constant MAX_LTV_LENGTH = 2;

/// @dev The length of the bytes encoded amount.
uint256 constant AMOUNT_LENGTH = 32;

/// @dev The offset of the collateral address and maxLtv.
uint256 constant AMOUNT_OFFSET = ADDR_LENGTH + MAX_LTV_LENGTH;

/// @dev The offset of an encoded pool allocation.
uint256 constant POOL_OFFSET = AMOUNT_OFFSET + AMOUNT_LENGTH;

library AllocationLib {
    using BytesLib for bytes;

    /// @notice Decodes the first pool in the given bytes encoded liquidity allocation.
    /// @param allocation The bytes encoded liquidity allocation.
    /// @param start The index at which to decode the pool.
    /// @return asset The collateral asset to lend against.
    /// @return amount The amount to lend.
    /// @return maxLtv The maximum LTV to lend this liquidity at.
    function decode(
        bytes memory allocation,
        uint256 start
    ) internal pure returns (address asset, uint256 amount, uint16 maxLtv) {
        asset = allocation.toAddress(start);
        maxLtv = allocation.toUint16(start + ADDR_LENGTH);
        amount = allocation.toUint256(start + AMOUNT_OFFSET);
    }
}
