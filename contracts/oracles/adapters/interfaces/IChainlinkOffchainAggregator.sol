// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IChainlinkOffchainAggregator {
    function minAnswer() external view returns (int192);
    function maxAnswer() external view returns (int192);
}
