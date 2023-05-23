// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

library BytesLib {
    /// @dev Thrown in case casting expects to read out-of-bounds data.
    error CastOutOfBounds(uint256 length);

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
    ) internal pure returns (uint16 value) {
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
