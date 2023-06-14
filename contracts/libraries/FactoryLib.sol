// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPool} from "contracts/interfaces/IPool.sol";
import {IFactory} from "contracts/interfaces/IFactory.sol";

library FactoryLib {
    bytes32 internal constant POOL_INIT_CODE_HASH = 0xa598dd2fba360510c5a8f02f44423a4468e902df5857dbce3ca162a43a3a31ff;

    /// @notice Deterministically computes the pool address given the factory and pool parameters.
    /// @param factory The Morpho Blue factory contract address.
    /// @param collateral The asset that can be used as collateral to borrow from the pool.
    /// @param asset The asset that can be borrowed from the pool.
    /// @return The contract address of the pool.
    function getPool(IFactory factory, address asset, address collateral) internal pure returns (IPool) {
        return IPool(
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                hex"ff", factory, keccak256(abi.encode(asset, collateral)), POOL_INIT_CODE_HASH
                            )
                        )
                    )
                )
            )
        );
    }
}
