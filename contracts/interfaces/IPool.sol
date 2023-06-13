// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IPool {
    function allowance(address spender, uint256 amount) external view returns (uint256);
    function liquidity(uint256 bucket) external view returns (uint256);

    function supplyBalanceOf(address owner, uint256 bucket) external view returns (uint256);
    function borrowBalanceOf(address owner, uint256 bucket) external view returns (uint256);
    function collateralBalanceOf(address owner) external view returns (uint256);

    function approve(address spender, uint256 amount) external;

    function depositCollateral(uint256 amount, address onBehalf) external;
    function withdrawCollateral(uint256 amount, address onBehalf, address receiver) external;

    function supply(uint256 amount, uint256 bucket, address onBehalf) external;
    function borrow(uint256 amount, uint256 bucket, address onBehalf) external;
    function repay(uint256 amount, uint256 bucket, address onBehalf) external;
    function withdraw(uint256 amount, uint256 bucket, address onBehalf, address receiver) external;
}
