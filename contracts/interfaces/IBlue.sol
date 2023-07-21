// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import {Market} from "@morpho-blue/libraries/MarketLib.sol";

interface IBlue {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;

    function collateral(bytes32, address) external view returns (uint256);
    function supplyShare(bytes32, address) external view returns (uint256);
    function borrowShare(bytes32, address) external view returns (uint256);

    function isApproved(address, address) external view returns (bool);
    function isIrmEnabled(address) external view returns (bool);
    function isLltvEnabled(uint256) external view returns (bool);
    function setApproval(address manager, bool isAllowed) external;

    function totalSupply(bytes32) external view returns (uint256);
    function totalSupplyShares(bytes32) external view returns (uint256);
    function totalBorrow(bytes32) external view returns (uint256);
    function totalBorrowShares(bytes32) external view returns (uint256);
    function lastUpdate(bytes32) external view returns (uint256);

    function fee(bytes32) external view returns (uint256);
    function feeRecipient() external view returns (address);
    function setFee(Market calldata market, uint256 newFee) external;
    function setFeeRecipient(address recipient) external;

    function enableIrm(address irm) external;
    function enableLltv(uint256 lltv) external;
    function createMarket(Market calldata market) external;

    function supplyCollateral(Market calldata market, uint256 amount, address onBehalf) external;
    function withdrawCollateral(Market calldata market, uint256 amount, address onBehalf) external;
    function supply(Market calldata market, uint256 amount, address onBehalf) external;
    function withdraw(Market calldata market, uint256 amount, address onBehalf) external;
    function borrow(Market calldata market, uint256 amount, address onBehalf) external;
    function repay(Market calldata market, uint256 amount, address onBehalf) external;

    function liquidate(Market calldata market, address borrower, uint256 seized) external;
}
