// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseOracle} from "./BaseOracle.sol";
import {UniswapV3CollateralAdapter} from "./adapters/UniswapV3CollateralAdapter.sol";

contract UniswapV3Oracle is BaseOracle, UniswapV3CollateralAdapter {
    constructor(address pool, uint32 delay, uint256 priceScale)
        BaseOracle(priceScale)
        UniswapV3CollateralAdapter(pool, delay)
    {}

    function BORROWABLE_FEED() external view returns (string memory, address) {}

    function BORROWABLE_SCALE() external pure returns (uint256) {
        return 1e18;
    }

    function borrowableToBasePrice() external pure returns (uint256) {
        return 1e18;
    }
}
