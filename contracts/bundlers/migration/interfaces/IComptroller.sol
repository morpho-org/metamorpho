// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IComptroller {
    function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory);
}
