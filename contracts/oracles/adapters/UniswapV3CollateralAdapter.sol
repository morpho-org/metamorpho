// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {OracleFeed} from "../libraries/OracleFeed.sol";
import {UniswapV3PoolLib} from "../libraries/UniswapV3PoolLib.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract UniswapV3CollateralAdapter is BaseOracle {
    using UniswapV3PoolLib for IUniswapV3Pool;

    IUniswapV3Pool internal immutable _UNI_V3_COLLATERAL_POOL;
    uint32 internal immutable _UNI_V3_COLLATERAL_DELAY;

    constructor(address pool, uint32 delay) {
        _UNI_V3_COLLATERAL_POOL = IUniswapV3Pool(pool);
        _UNI_V3_COLLATERAL_DELAY = delay;
        COLLATERAL_SCALE = 1e18;
    }

    function COLLATERAL_FEED() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(_UNI_V3_COLLATERAL_POOL));
    }

    function collateralPrice() public view virtual override returns (uint256) {
        return _UNI_V3_COLLATERAL_POOL.price(_UNI_V3_COLLATERAL_DELAY);
    }
}
