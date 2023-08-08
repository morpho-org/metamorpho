// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import {IOracle as IBlueOracle} from "@morpho-blue/interfaces/IOracle.sol";

enum OracleFeed {
    UNISWAP_V3,
    CHAINLINK,
    REDSTONE,
    PYTH,
    KAIKO,
    RATED,
    API3
}

interface IOracle is IBlueOracle {
    function FEED1() external view returns (OracleFeed, address);
    function FEED2() external view returns (OracleFeed, address);
}
