// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library ErrorsLib {
    string internal constant UNINITIATED = "uninitiated";

    string internal constant DEADLINE_EXPIRED = "deadline expired";

    string internal constant ZERO_ADDRESS = "zero address";

    string internal constant BUNDLER_ADDRESS = "bundler address";

    string internal constant ZERO_AMOUNT = "zero amount";

    string internal constant ZERO_SHARES = "zero shares";

    string internal constant ONLY_WNATIVE = "only wrapped native";
}
