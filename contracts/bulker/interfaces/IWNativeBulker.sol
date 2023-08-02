// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IWNativeBulker {
    /* ERRORS */

    /// @notice Thrown when the bulker receives some native token from another contract than Wrapped Native.
    error OnlyWNative();
}
