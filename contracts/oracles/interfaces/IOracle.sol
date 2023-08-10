// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import {IOracle as IBlueOracle} from "@morpho-blue/interfaces/IOracle.sol";

interface IOracle is IBlueOracle {
    function FEED_COLLATERAL() external view returns (string memory, address);
    function FEED_BORROWABLE() external view returns (string memory, address);
}
