// SPDX-License-Identifier: GPL-2.0-OR-LATER
pragma solidity >=0.5.0;

interface IChainlinkOffchainAggregator {
    function minAnswer() external view returns (int192);
    function maxAnswer() external view returns (int192);
}
