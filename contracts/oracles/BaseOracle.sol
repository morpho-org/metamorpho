// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";

import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";

abstract contract BaseOracle is IOracle {
    using FullMath for uint256;

    /// @dev The scale must be 1e36 * 10^(decimals of borrowable token - decimals of collateral token).
    uint256 public immutable PRICE_SCALE;

    // @dev The collateral price's unit.
    uint256 public immutable COLLATERAL_SCALE;

    // @dev The borrowable price's unit.
    uint256 public immutable BORROWABLE_SCALE;

    constructor(uint256 priceScale) {
        PRICE_SCALE = priceScale;
    }

    function price() external view returns (uint256) {
        // Using FullMath to avoid overflowing because of PRICE_SCALE.
        return PRICE_SCALE.mulDiv(collateralPrice() * BORROWABLE_SCALE, borrowablePrice() * COLLATERAL_SCALE);
    }

    function collateralPrice() public view virtual returns (uint256);
    function borrowablePrice() public view virtual returns (uint256);
}
