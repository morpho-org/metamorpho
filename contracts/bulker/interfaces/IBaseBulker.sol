// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IBaseBulker {
    /* TYPES */

    /// @notice Contains the `v`, `r` and `s` parameters of an ECDSA signature.
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /* ERRORS */

    /// @notice Thrown when an address parameter is the bulker's address.
    error AddressIsBulker();

    /// @notice Thrown when an address used as parameter is the zero address.
    error AddressIsZero();

    /// @notice Thrown when an amount used as parameter is zero.
    error AmountIsZero();

    /// @notice Thrown when the bulker is not initiated.
    error Uninitiated();
}
