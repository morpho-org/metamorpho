// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPool} from "contracts/interfaces/IPool.sol";

library PoolLib {
    /// @dev Calculates the hypothetical APR after having supplied liquidity at maxLtv on the given pool.
    function apr(IPool pool, uint256 maxLtv, uint256 supplied) external view returns (uint256) {
        // TODO: implement a way to calculate the hypothetical APR
    }
}
