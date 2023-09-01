// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IComptroller {
    function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory);
}
