// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface ICompoundV3 {
    function allowBySig(
        address owner,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
