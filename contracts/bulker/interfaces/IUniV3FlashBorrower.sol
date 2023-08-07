// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IUniV3FlashLender {
    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external;
}
