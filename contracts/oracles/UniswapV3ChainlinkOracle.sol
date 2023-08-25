// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract UniswapV3ChainlinkOracle is BaseOracle, UniswapV3CollateralAdapter, ChainlinkBorrowableAdapter {
    constructor(
        uint256 scaleFactor,
        address pool,
        uint32 collateralPriceWindow,
        address collateralPriceQuoteToken,
        address feed,
        uint256 borrowableStaleTimeout,
        uint256 borrowableBoundOffsetFactor
    )
        BaseOracle(scaleFactor)
        UniswapV3CollateralAdapter(pool, collateralPriceWindow, collateralPriceQuoteToken)
        ChainlinkBorrowableAdapter(feed, borrowableStaleTimeout, borrowableBoundOffsetFactor)
    {}
}
