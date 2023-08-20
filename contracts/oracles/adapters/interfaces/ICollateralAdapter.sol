// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface ICollateralAdapter {
    function COLLATERAL_FEED() external view returns (string memory, address);
    function COLLATERAL_SCALE() external view returns (uint256);
    function collateralToBasePrice() external view returns (uint256);
}
