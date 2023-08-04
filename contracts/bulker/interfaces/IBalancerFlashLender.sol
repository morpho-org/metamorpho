// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IBalancerFlashLender {
    function flashLoan(address receiver, address[] calldata tokens, uint256[] calldata amounts, bytes calldata userData)
        external
        payable;
}
