// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

struct PoolLiquidityAllocation {
    uint256 maxLtv;
    uint256 amount;
}

struct LiquidityAllocation {
    address pool;
    PoolLiquidityAllocation[] liquidity; // TODO: could be flattened if most supply cases have a single maxLtv per pool
}
