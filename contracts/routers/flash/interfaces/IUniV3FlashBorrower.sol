// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniV3FlashBorrower {
    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external;
}
