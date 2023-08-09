// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

/// @title BaseSelfMulticall
/// @notice Enables calling multiple functions in a single call to the same contract (self).
abstract contract BaseSelfMulticall {
    /* INTERNAL */

    function _multicall(bytes[] memory data) internal returns (bytes[] memory results) {
        results = new bytes[](data.length);

        for (uint256 i; i < data.length; ++i) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                if (result.length < 68) revert();

                assembly {
                    result := add(result, 0x04)
                }

                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }
}
