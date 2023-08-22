// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IFlashBorrower {
    function onFlashLoan() external;
}
