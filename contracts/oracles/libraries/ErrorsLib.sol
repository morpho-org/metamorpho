// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library ErrorsLib {
    string internal constant ZERO_ADDRESS = "zero address";

    string internal constant ZERO_INPUT = "zero input";

    string internal constant INVALID_QUOTE_TOKEN = "invalid quote token";

    string internal constant STALE_PRICE = "price is stale";
}
