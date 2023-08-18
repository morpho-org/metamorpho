// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IMulticall {
    function multicall(uint256 deadline, bytes[] calldata data) external payable returns (bytes[] memory results);
}
