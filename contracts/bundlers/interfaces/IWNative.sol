// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IWNative {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function approve(address guy, uint256 wad) external returns (bool);
    function transferFrom(address src, address dst, uint256 wad) external returns (bool);
}
