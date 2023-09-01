// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface ICToken {
    function underlying() external returns (address);

    function balanceOf(address) external view returns (uint256);

    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

    function borrow(uint256 borrowAmount) external returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);
}
