// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface ICompoundV3 {
    function name() external view returns (string memory);

    function version() external view returns (string memory);

    function baseToken() external view returns (address);

    function balanceOf(address) external view returns (uint256);

    function supply(address asset, uint256 amount) external;

    function supplyTo(address dst, address asset, uint256 amount) external;

    function supplyFrom(address from, address dst, address asset, uint256 amount) external;

    function withdraw(address asset, uint256 amount) external;

    function withdrawFrom(address src, address to, address asset, uint256 amount) external;

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
