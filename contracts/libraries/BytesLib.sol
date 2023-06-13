// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

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

library BytesLib {
    /// @dev Thrown in case casting expects to read out-of-bounds data.
    error CastOutOfBounds(uint256 length);

    /// @dev Casts a slice of 20 bytes to an address.
    /// @param data The bytes containing data.
    /// @param start The index at which the bytes slice starts.
    /// @return value The decoded address.
    function toAddress(bytes memory data, uint256 start) internal pure returns (address value) {
        uint256 length = data.length;
        if (length < start + ADDR_LENGTH) revert CastOutOfBounds(length);

        assembly {
            value := div(mload(add(data, add(start, 0x20))), 0x1000000000000000000000000)
        }
    }

    /// @dev Casts a slice of 2 bytes to a uint16.
    /// @param data The bytes containing data.
    /// @param start The index at which the bytes slice starts.
    /// @return value The decoded uint16.
    function toUint16(bytes memory data, uint256 start) internal pure returns (uint16 value) {
        uint256 length = data.length;
        if (length < start + MAX_LTV_LENGTH) revert CastOutOfBounds(length);

        assembly {
            value := mload(add(data, add(start, 0x2)))
        }
    }

    /// @dev Casts a slice of 32 bytes to a uint256.
    /// @param data The bytes containing data.
    /// @param start The index at which the bytes slice starts.
    /// @return value The decoded uint256.
    function toUint256(bytes memory data, uint256 start) internal pure returns (uint256 value) {
        uint256 length = data.length;
        if (length < start + AMOUNT_LENGTH) revert CastOutOfBounds(length);

        assembly {
            value := mload(add(data, add(start, 0x20)))
        }
    }

    /// @notice Decodes the first pool in the given bytes encoded liquidity allocation.
    /// @param allocation The bytes encoded liquidity allocation.
    /// @param start The index at which to decode the pool.
    /// @return asset The collateral asset to lend against.
    /// @return amount The amount to lend.
    /// @return maxLtv The maximum LTV to lend this liquidity at.
    function decodePoolAllocation(bytes memory allocation, uint256 start)
        internal
        pure
        returns (address asset, uint256 amount, uint16 maxLtv)
    {
        asset = toAddress(allocation, start);
        maxLtv = toUint16(allocation, start + ADDR_LENGTH);
        amount = toUint256(allocation, start + AMOUNT_OFFSET);
    }

    /// @notice Decodes the first risk parameters in the given bytes encoded collateralization.
    /// @param collateralization The bytes encoded liquidity collateralization.
    /// @param start The index at which to decode the pool.
    /// @return asset The collateral asset to lend against.
    /// @return maxLtv The maximum LTV to lend the associated liquidity at.
    function decodeCollateralLtv(bytes memory collateralization, uint256 start)
        internal
        pure
        returns (address asset, uint16 maxLtv)
    {
        asset = toAddress(collateralization, start);
        maxLtv = toUint16(collateralization, start + ADDR_LENGTH);
    }
}
