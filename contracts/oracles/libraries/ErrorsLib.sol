// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library ErrorsLib {
    string internal constant ZERO_ADDRESS = "zero address";

    string internal constant ZERO_INPUT = "zero input";

    string internal constant INVALID_QUOTE_TOKEN = "invalid quote token";

    string internal constant INVALID_ANSWER = "invalid answer";

    string internal constant SEQUENCER_DOWN = "sequencer down";

    string internal constant GRACE_PERIOD_NOT_OVER = "grace period not over";
}
