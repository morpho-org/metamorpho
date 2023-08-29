// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IBalancerFlashLender {
    function flashLoan(address receiver, address[] calldata tokens, uint256[] calldata amounts, bytes calldata userData)
        external
        payable;
}
