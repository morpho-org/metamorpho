// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IOracle} from "./interfaces/IOracle.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {OracleFeed} from "./libraries/OracleFeed.sol";
import {MathLib} from "@morpho-blue/libraries/MathLib.sol";
import {UniswapV3PoolLib} from "./libraries/UniswapV3PoolLib.sol";

import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";
import {UniswapV3BorrowableAdapter} from "./adapters/UniswapV3BorrowableAdapter.sol";

contract UniswapV3Oracle is UniswapV3CollateralAdapter, UniswapV3BorrowableAdapter, IOracle {
    using MathLib for uint256;
    using UniswapV3PoolLib for IUniswapV3Pool;

    constructor(
        address collateralPool,
        address borrowablePool,
        uint32 collateralPriceDelay,
        uint32 borrowablePriceDelay
    )
        UniswapV3CollateralAdapter(collateralPool, collateralPriceDelay)
        UniswapV3BorrowableAdapter(borrowablePool, borrowablePriceDelay)
    {}

    function FEED_COLLATERAL() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(UNI_V3_COLLATERAL_POOL));
    }

    function FEED_BORROWABLE() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(UNI_V3_BORROWABLE_POOL));
    }

    function price() external view returns (uint256) {
        return UNI_V3_COLLATERAL_POOL.price(UNI_V3_COLLATERAL_DELAY).wDivDown(
            UNI_V3_BORROWABLE_POOL.price(UNI_V3_BORROWABLE_DELAY)
        );
    }
}
