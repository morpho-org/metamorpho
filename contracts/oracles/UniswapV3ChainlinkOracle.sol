// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";
import {ChainlinkBorrowableAdapter} from "./adapters/ChainlinkBorrowableAdapter.sol";

contract UniswapV3ChainlinkOracle is BaseOracle, UniswapV3CollateralAdapter, ChainlinkBorrowableAdapter {
    constructor(address pool, address feed, uint32 collateralPriceDelay, uint256 priceScale)
        BaseOracle(priceScale)
        UniswapV3CollateralAdapter(pool, collateralPriceDelay)
        ChainlinkBorrowableAdapter(feed)
    {}

    function collateralScale() public view override(BaseOracle, UniswapV3CollateralAdapter) returns (uint256) {
        return UniswapV3CollateralAdapter.collateralScale();
    }

    function borrowableScale() public view override(BaseOracle, ChainlinkBorrowableAdapter) returns (uint256) {
        return ChainlinkBorrowableAdapter.borrowableScale();
    }

    function collateralToBasePrice() public view override(BaseOracle, UniswapV3CollateralAdapter) returns (uint256) {
        return UniswapV3CollateralAdapter.collateralToBasePrice();
    }

    function borrowableToBasePrice() public view override(BaseOracle, ChainlinkBorrowableAdapter) returns (uint256) {
        return ChainlinkBorrowableAdapter.borrowableToBasePrice();
    }
}
