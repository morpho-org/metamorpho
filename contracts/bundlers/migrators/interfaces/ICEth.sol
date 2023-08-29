// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface ICEth {
    function repayBorrowBehalf(address borrower) external payable;
}
