// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IPool {
    function approve(address spender, uint256 amount) external;

    function allowance(
        address spender,
        uint256 amount
    ) external returns (uint256);

    function supply(uint256 amount, uint256 maxLtv, address onBehalf) external;

    function withdraw(
        uint256 amount,
        uint256 maxLtv,
        address onBehalf,
        address receiver
    ) external;

    function liquidity(uint256 maxLtv) external returns (uint256);
}
