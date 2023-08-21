// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";

import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";

abstract contract BaseOracle is IOracle {
    using FullMath for uint256;

    /// @dev The scale must be 1e36 * 10^(decimals of borrowable token - decimals of collateral token).
    uint256 public immutable PRICE_SCALE;

    constructor(uint256 priceScale) {
        PRICE_SCALE = priceScale;
    }

    function price() external view returns (uint256) {
        // Using FullMath to avoid overflowing because of PRICE_SCALE.
        return
            PRICE_SCALE.mulDiv(collateralToBasePrice() * borrowableScale(), borrowableToBasePrice() * collateralScale());
    }

    function collateralScale() public view virtual returns (uint256) {}
    function borrowableScale() public view virtual returns (uint256) {}
    function collateralToBasePrice() public view virtual returns (uint256) {}
    function borrowableToBasePrice() public view virtual returns (uint256) {}
}
