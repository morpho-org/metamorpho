// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IChainlinkAggregatorV3} from "contracts/oracles/adapters/interfaces/IChainlinkAggregatorV3.sol";
import {IChainlinkOffchainAggregator} from "contracts/oracles/adapters/interfaces/IChainlinkOffchainAggregator.sol";

contract ChainlinkOffchainAggregatorMock is IChainlinkOffchainAggregator {
    int192 public minAnswer;
    int192 public maxAnswer = type(int192).max;
}

contract ChainlinkAggregatorV3Mock is IChainlinkAggregatorV3 {
    string public description = "desciption";
    uint256 public version = 1;
    uint8 public decimals;
    int256 public latestAnswer;
    address public aggregator;

    constructor() {
        decimals = 8;
        latestAnswer = 1e8;
        aggregator = address(new ChainlinkOffchainAggregatorMock());
    }

    function setDecimals(uint8 newDecimals) external {
        decimals = newDecimals;
    }

    function setLatestAnswer(int256 newAnswer) external {
        latestAnswer = newAnswer;
    }

    function getRoundData(uint80)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, latestAnswer, 0, 0, 0);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, latestAnswer, 0, 0, 0);
    }
}
