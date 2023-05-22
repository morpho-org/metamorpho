// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {BytesLib} from "src/libraries/BytesLib.sol";

library AllocationLib {
    using BytesLib for bytes;

    /// @dev The length of the bytes encoded address.
    uint256 private constant ADDR_LENGTH = 20;

    /// @dev The length of the bytes encoded maxLtv.
    uint256 private constant MAX_LTV_LENGTH = 2;

    /// @dev The length of the bytes encoded amount.
    uint256 private constant AMOUNT_LENGTH = 32;

    /// @dev The offset of the collateral address and maxLtv.
    uint256 private constant NEXT_OFFSET = ADDR_LENGTH + MAX_LTV_LENGTH;

    /// @dev The offset of an encoded pool allocation.
    uint256 private constant POP_OFFSET = NEXT_OFFSET + AMOUNT_LENGTH;

    /// @notice Decodes the first pool in the given bytes encoded liquidity allocation.
    /// @param allocation The bytes encoded liquidity allocation.
    /// @return asset The collateral asset to lend against.
    /// @return amount The amount to lend.
    /// @return maxLtv The maximum LTV to lend this liquidity at.
    function decodeFirst(
        bytes memory allocation
    )
        internal
        pure
        returns (
            address asset,
            uint256 amount,
            uint16 maxLtv,
            bytes memory rest
        )
    {
        asset = allocation.toAddress(0);
        maxLtv = allocation.toUint16(ADDR_LENGTH);
        amount = allocation.toUint256(NEXT_OFFSET);
        rest = allocation.slice(NEXT_OFFSET, allocation.length - NEXT_OFFSET);
    }
}
