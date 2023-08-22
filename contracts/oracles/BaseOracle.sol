// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";

import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";

/// @dev The scale as expected by Morpho Blue.
uint256 constant PRICE_SCALE = 1e36;

abstract contract BaseOracle is IOracle {
    using FullMath for uint256;

    // @dev The collateral price's unit.
    uint256 public immutable COLLATERAL_SCALE;

    // @dev The borrowable price's unit.
    uint256 public immutable BORROWABLE_SCALE;

    function price() external view returns (uint256) {
        // Using FullMath to avoid overflowing because of PRICE_SCALE.
        return PRICE_SCALE.mulDiv(collateralPrice() * BORROWABLE_SCALE, borrowablePrice() * COLLATERAL_SCALE);
    }

    function collateralPrice() public view virtual returns (uint256);
    function borrowablePrice() public view virtual returns (uint256);
}
