// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPool} from "src/interfaces/IPool.sol";

library PoolLib {
    /// @dev Calculates the hypothetical APR after having supplied and/or withdrawn liquidity at maxLtv on the given pool.
    function apr(
        IPool pool,
        uint256 maxLtv,
        uint256 supplied,
        uint256 withdrawn
    ) external returns (uint256) {
        // TODO: implement a way to calculate the hypothetical APR
    }
}
