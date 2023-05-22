// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

library BytesLib {
    uint256 internal constant MAX_LENGTH = type(uint256).max - 31;

    /// @dev Thrown when a slice is too large.
    error SliceOverflow();

    /// @dev Thrown when slicing expects to read out-of-bounds data.
    error SliceOutOfBounds(uint256 length);

    /// @dev Thrown in case casting expects to read out-of-bounds data.
    error CastOutOfBounds(uint256 length);

    function slice(
        bytes memory data,
        uint256 start,
        uint256 length
    ) internal pure returns (bytes memory value) {
        if (length > MAX_LENGTH) revert SliceOverflow();

        uint256 dataLength = data.length;
        if (dataLength < start + length) revert SliceOutOfBounds(dataLength);

        assembly {
            switch iszero(length)
            case 0 {
                // Get a location of some free memory and store it in value as
                // Solidity does for memory variables.
                value := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(
                    add(value, lengthmod),
                    mul(0x20, iszero(lengthmod))
                )
                let end := add(mc, length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(
                        add(add(data, lengthmod), mul(0x20, iszero(lengthmod))),
                        start
                    )
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(value, length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            // if we want a zero-length slice let's just return a zero-length array
            default {
                value := mload(0x40)
                // zero out the 32 bytes slice we are about to return
                // we need to do it because Solidity does not garbage collect
                mstore(value, 0)

                mstore(0x40, add(value, 0x20))
            }
        }
    }

    function toAddress(
        bytes memory data,
        uint256 start
    ) internal pure returns (address value) {
        uint256 length = data.length;
        if (length < start + 20) revert CastOutOfBounds(length);

        assembly {
            value := div(
                mload(add(data, add(start, 0x20))),
                0x1000000000000000000000000
            )
        }
    }

    function toUint16(
        bytes memory data,
        uint256 start
    ) internal pure returns (uint24 value) {
        uint256 length = data.length;
        if (length < start + 2) revert CastOutOfBounds(length);

        assembly {
            value := mload(add(data, add(start, 0x2)))
        }
    }

    function toUint256(
        bytes memory data,
        uint256 start
    ) internal pure returns (uint256 value) {
        uint256 length = data.length;
        if (length < start + 32) revert CastOutOfBounds(length);

        assembly {
            value := mload(add(data, add(start, 0x20)))
        }
    }
}
