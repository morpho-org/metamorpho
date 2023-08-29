// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface ICToken {
    function underlying() external returns (address);

    function repayBorrowBehalf(address borrower, uint256 repayAmount) external;

    function redeem(uint256 redeemTokens) external;
}
