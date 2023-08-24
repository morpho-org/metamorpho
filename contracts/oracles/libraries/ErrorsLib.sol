// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library ErrorsLib {
    string internal constant ZERO_ADDRESS = "zero address";

    string internal constant ZERO_INPUT = "zero input";

    string internal constant NEGATIVE_ANSWER = "negative answer";

    string internal constant NEGATIVE_MIN_ANSWER = "negative min answer";

    string internal constant INVALID_BOUND_OFFSET_FACTOR = "bound offset factor must be between 0 and 50%";

    string internal constant INVALID_QUOTE_TOKEN = "invalid quote token";

    string internal constant ANSWER_OUT_OF_BOUNDS = "answer out of bounds";

    string internal constant SEQUENCER_DOWN = "sequencer down";

    string internal constant GRACE_PERIOD_NOT_OVER = "grace period not over";
}
