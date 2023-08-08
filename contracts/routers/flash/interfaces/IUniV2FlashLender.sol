// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IUniV2FlashLender {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}
