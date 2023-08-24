// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";

import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {OracleFeed} from "../libraries/OracleFeed.sol";
import {UniswapV3PoolLib} from "../libraries/UniswapV3PoolLib.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract UniswapV3BorrowableAdapter is BaseOracle {
    using UniswapV3PoolLib for IUniswapV3Pool;

    IUniswapV3Pool private immutable _UNI_V3_BORROWABLE_POOL;

    uint32 public immutable BORROWABLE_WINDOW;
    bool public immutable BORROWABLE_PRICE_INVERSED;

    /// @dev Warning: assumes `quoteToken` is either the pool's token0 or token1.
    constructor(address pool, uint32 window, address quoteToken) {
        require(pool != address(0), ErrorsLib.ZERO_ADDRESS);
        require(window > 0, ErrorsLib.ZERO_INPUT);

        _UNI_V3_BORROWABLE_POOL = IUniswapV3Pool(pool);

        address token0 = _UNI_V3_BORROWABLE_POOL.token0();
        address token1 = _UNI_V3_BORROWABLE_POOL.token1();
        require(quoteToken == token0 || quoteToken == token1, ErrorsLib.INVALID_QUOTE_TOKEN);

        BORROWABLE_WINDOW = window;
        BORROWABLE_PRICE_INVERSED = quoteToken == token0;

        BORROWABLE_SCALE = 1 << 128;
    }

    function BORROWABLE_FEED() external view returns (string memory, address) {
        return (OracleFeed.UNISWAP_V3, address(_UNI_V3_BORROWABLE_POOL));
    }

    function borrowablePrice() public view virtual override returns (uint256) {
        return _UNI_V3_BORROWABLE_POOL.priceX128(BORROWABLE_WINDOW, BORROWABLE_PRICE_INVERSED);
    }
}
