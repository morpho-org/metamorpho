// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IBorrowableAdapter} from "./interfaces/IBorrowableAdapter.sol";

import {OracleFeed} from "../libraries/OracleFeed.sol";

abstract contract NeutralBorrowableAdapter is IBorrowableAdapter {
    function BORROWABLE_FEED() external pure returns (string memory, address) {
        return (OracleFeed.NEUTRAL, address(0));
    }

    function borrowableScale() external view virtual returns (uint256) {
        return 1e18;
    }

    function borrowableToBasePrice() external view virtual returns (uint256) {
        return 1e18;
    }
}
