// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IBorrowableAdapter {
    function BORROWABLE_FEED() external view returns (string memory, address);
    function BORROWABLE_SCALE() external view returns (uint256);
    function borrowableToBasePrice() external view returns (uint256);
}
