// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

/// @title BaseSelfMulticall
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Enables calling multiple functions in a single call to the same contract (self).
/// @dev Based on Uniswap work: https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/Multicall.sol
abstract contract BaseSelfMulticall {
    /* INTERNAL */

    /// @notice Executes a series of delegate calls to the contract itself.
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
