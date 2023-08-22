// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {OracleFeed} from "../libraries/OracleFeed.sol";
import {UniswapV3PoolLib} from "../libraries/UniswapV3PoolLib.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract UniswapV3CollateralAdapter is BaseOracle {
    using UniswapV3PoolLib for IUniswapV3Pool;

    IUniswapV3Pool private immutable _UNI_V3_COLLATERAL_POOL;
    uint32 private immutable _UNI_V3_COLLATERAL_DELAY;

    constructor(address pool, uint32 delay) {
        require(pool != address(0), ErrorsLib.ZERO_ADDRESS);
        require(delay > 0, ErrorsLib.ZERO_INPUT);

        _UNI_V3_COLLATERAL_POOL = IUniswapV3Pool(pool);
        _UNI_V3_COLLATERAL_DELAY = delay;
        COLLATERAL_SCALE = 1e18;
    }

    function COLLATERAL_FEED() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(_UNI_V3_COLLATERAL_POOL));
    }

    function COLLATERAL_DELAY() external view returns (uint32) {
        return _UNI_V3_COLLATERAL_DELAY;
    }

    function collateralPrice() public view virtual override returns (uint256) {
        return _UNI_V3_COLLATERAL_POOL.price(_UNI_V3_COLLATERAL_DELAY);
    }
}
