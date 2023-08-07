// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IUniV2FlashLender {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
