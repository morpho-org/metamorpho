// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {OracleFeed} from "../libraries/OracleFeed.sol";
import {UniswapV3PoolLib} from "../libraries/UniswapV3PoolLib.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract UniswapV3BorrowableAdapter is BaseOracle {
    using UniswapV3PoolLib for IUniswapV3Pool;

    IUniswapV3Pool private immutable _UNI_V3_BORROWABLE_POOL;
    uint32 private immutable _UNI_V3_BORROWABLE_WINDOW;
    bool private immutable _PRICE_INVERSED;

    /// @dev Warning: assumes `quoteToken` is either the pool's token0 or token1.
    constructor(address pool, uint32 window, address quoteToken) {
        _UNI_V3_BORROWABLE_POOL = IUniswapV3Pool(pool);
        _UNI_V3_BORROWABLE_WINDOW = window;
        _PRICE_INVERSED = quoteToken == _UNI_V3_BORROWABLE_POOL.token0();

        require(_PRICE_INVERSED || quoteToken == _UNI_V3_BORROWABLE_POOL.token1(), "incorrect quote token");

        BORROWABLE_SCALE = 1 << 128;
    }

    function BORROWABLE_FEED() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(_UNI_V3_BORROWABLE_POOL));
    }

    function BORROWABLE_WINDOW() external view returns (uint32) {
        return _UNI_V3_BORROWABLE_WINDOW;
    }

    function borrowablePrice() public view virtual override returns (uint256) {
        return _UNI_V3_BORROWABLE_POOL.priceX128(_UNI_V3_BORROWABLE_WINDOW, _PRICE_INVERSED);
    }
}
