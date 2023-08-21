// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {NeutralBorrowableAdapter} from "./adapters/NeutralBorrowableAdapter.sol";
import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";

contract UniswapV3Oracle is BaseOracle, UniswapV3CollateralAdapter, NeutralBorrowableAdapter {
    constructor(address pool, uint32 delay, uint256 priceScale)
        BaseOracle(priceScale)
        UniswapV3CollateralAdapter(pool, delay)
    {}

    function collateralScale() public view override(BaseOracle, UniswapV3CollateralAdapter) returns (uint256) {
        return UniswapV3CollateralAdapter.collateralScale();
    }

    function borrowableScale() public view override(BaseOracle, NeutralBorrowableAdapter) returns (uint256) {
        return NeutralBorrowableAdapter.borrowableScale();
    }

    function collateralToBasePrice() public view override(BaseOracle, UniswapV3CollateralAdapter) returns (uint256) {
        return UniswapV3CollateralAdapter.collateralToBasePrice();
    }

    function borrowableToBasePrice() public view override(BaseOracle, NeutralBorrowableAdapter) returns (uint256) {
        return NeutralBorrowableAdapter.borrowableToBasePrice();
    }
}
