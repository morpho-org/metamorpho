// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";

import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";

abstract contract BaseOracle is IOracle {
    /// @dev The scale must be 1e36 * 10^(decimals of borrowable token - decimals of collateral token).
    uint256 public immutable PRICE_SCALE;

    constructor(uint256 priceScale) {
        require(priceScale > 0, "BaseOracle: invalid price scale");

        PRICE_SCALE = priceScale;
    }

    function price() external view returns (uint256) {
        return FullMath.mulDiv(
            collateralPriceToBase() * borrowableScale(),
            PRICE_SCALE, // Using FullMath to avoid overflowing because of PRICE_SCALE.
            borrowablePriceToBase() * collateralScale()
        );
    }

    function collateralPriceToBase() public view virtual returns (uint256) {}
    function borrowablePriceToBase() public view virtual returns (uint256) {}
    function collateralScale() public view virtual returns (uint256) {}
    function borrowableScale() public view virtual returns (uint256) {}
}
