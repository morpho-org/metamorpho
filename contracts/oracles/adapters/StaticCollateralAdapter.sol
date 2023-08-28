// SPDX-License-Identifier: GPL-2.0-OR-LATER
pragma solidity ^0.8.0;

import {BaseOracle} from "../BaseOracle.sol";

abstract contract StaticCollateralAdapter is BaseOracle {
    constructor() {
        COLLATERAL_SCALE = 1;
    }

    function COLLATERAL_FEED() external pure returns (address) {
        return address(0);
    }

    function collateralPrice() public view virtual override returns (uint256) {
        return 1;
    }
}
