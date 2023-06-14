// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IFactory {
    function createPool(address asset, address collateral) external returns (address);
}
