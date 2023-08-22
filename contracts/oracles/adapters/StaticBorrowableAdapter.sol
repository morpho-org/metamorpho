// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OracleFeed} from "../libraries/OracleFeed.sol";

import {BaseOracle} from "../BaseOracle.sol";

abstract contract StaticBorrowableAdapter is BaseOracle {
    constructor() {
        BORROWABLE_SCALE = 1;
    }

    function BORROWABLE_FEED() external pure returns (string memory, address) {
        return (OracleFeed.STATIC, address(0));
    }

    function borrowablePrice() public view virtual override returns (uint256) {
        return 1;
    }
}
