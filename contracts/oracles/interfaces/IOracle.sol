// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import {IOracle as IBlueOracle} from "@morpho-blue/interfaces/IOracle.sol";

interface IOracle is IBlueOracle {
    function COLLATERAL_FEED() external view returns (string memory, address);
    function BORROWABLE_FEED() external view returns (string memory, address);

    function COLLATERAL_SCALE() external view returns (uint256);
    function BORROWABLE_SCALE() external view returns (uint256);
    function collateralToBasePrice() external view returns (uint256);
    function borrowableToBasePrice() external view returns (uint256);
}
