// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract UniswapV3ChainlinkOracle is BaseOracle, UniswapV3CollateralAdapter, ChainlinkBorrowableAdapter {
    constructor(
        uint256 priceScale,
        address pool,
        address feed,
        uint32 collateralPriceDelay,
        bool collateralPriceInversed
    )
        BaseOracle(priceScale)
        UniswapV3CollateralAdapter(pool, collateralPriceDelay, collateralPriceInversed)
        ChainlinkBorrowableAdapter(feed)
    {}
}
