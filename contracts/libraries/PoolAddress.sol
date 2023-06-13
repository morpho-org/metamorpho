// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

/// @title Provides functions for deriving a pool address from the factory.
library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xa598dd2fba360510c5a8f02f44423a4468e902df5857dbce3ca162a43a3a31ff;

    /// @notice Deterministically computes the pool address given the factory and pool parameters.
    /// @param factory The Morpho Blue factory contract address.
    /// @param collateral The asset that can be used as collateral to borrow from the pool.
    /// @param asset The asset that can be borrowed from the pool.
    /// @return The contract address of the pool.
    function computeAddress(address factory, address collateral, address asset) internal pure returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff", factory, keccak256(abi.encode(collateral, asset)), POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
