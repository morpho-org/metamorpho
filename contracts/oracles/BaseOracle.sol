// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";

import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";

abstract contract BaseOracle is IOracle {
    using FullMath for uint256;

    /// @dev The scale must be 10 ** (36 + decimals of borrowable token - decimals of collateral token), so the end
    /// price has 36 decimals of precision and automatically scales a collateral amount to a borrowable amount.
    uint256 public immutable SCALE_FACTOR;

    // @dev The collateral price's unit.
    uint256 public immutable COLLATERAL_SCALE;

    // @dev The borrowable price's unit.
    uint256 public immutable BORROWABLE_SCALE;

    constructor(uint256 scaleFactor) {
        SCALE_FACTOR = scaleFactor;
    }

    function price() external view returns (uint256) {
        // Using FullMath's 512 bit multiplication to avoid overflowing.
        uint256 collateralPriceInBorrowable = collateralPrice().mulDiv(BORROWABLE_SCALE, borrowablePrice());

        return SCALE_FACTOR.mulDiv(collateralPriceInBorrowable, COLLATERAL_SCALE);
    }

    function collateralPrice() public view virtual returns (uint256);
    function borrowablePrice() public view virtual returns (uint256);
}
