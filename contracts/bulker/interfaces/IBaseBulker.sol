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
}
