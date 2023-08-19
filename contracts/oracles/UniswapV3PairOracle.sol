// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";
import {MathLib} from "@morpho-blue/libraries/MathLib.sol";
import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";
import {UniswapV3PoolLib} from "./libraries/UniswapV3PoolLib.sol";

import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";
import {UniswapV3BorrowableAdapter} from "./adapters/UniswapV3BorrowableAdapter.sol";

contract UniswapV3Oracle is UniswapV3CollateralAdapter, UniswapV3BorrowableAdapter, IOracle {
    using MathLib for uint256;
    using UniswapV3PoolLib for IUniswapV3Pool;

    /// @dev The scale must be 1e36 * 10^(decimals of borrowable token - decimals of collateral token).
    uint256 public immutable PRICE_SCALE;

    constructor(
        address collateralPool,
        address borrowablePool,
        uint32 collateralPriceDelay,
        uint32 borrowablePriceDelay,
        uint256 scale
    )
        UniswapV3CollateralAdapter(collateralPool, collateralPriceDelay)
        UniswapV3BorrowableAdapter(borrowablePool, borrowablePriceDelay)
    {
        PRICE_SCALE = scale;
    }

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(UNI_V3_COLLATERAL_POOL));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(UNI_V3_BORROWABLE_POOL));
    }

    function price() external view returns (uint256) {
        return FullMath.mulDiv(
            UNI_V3_COLLATERAL_POOL.price(UNI_V3_COLLATERAL_DELAY),
            PRICE_SCALE,
            UNI_V3_BORROWABLE_POOL.price(UNI_V3_BORROWABLE_DELAY)
        );
    }
}
