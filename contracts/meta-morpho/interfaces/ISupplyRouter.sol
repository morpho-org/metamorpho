// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface ISupplyRouter {
    function supply(address asset, bytes calldata allocation, address onBehalf) external;

    function withdraw(address asset, bytes calldata allocation, address receiver) external;
}
