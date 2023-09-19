// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.2;

import {IMorpho, Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";

struct Pending {
    uint192 value;
    uint64 submittedAt;
}

struct MarketConfig {
    uint192 cap;
    uint64 withdrawRank;
}

struct MarketAllocation {
    MarketParams marketParams;
    uint256 assets;
}

interface IMetaMorpho is IERC4626 {
    function MORPHO() external view returns (IMorpho);

    function isAllocator(address target) external view returns (bool);
    function isRiskManager(address target) external view returns (bool);

    function fee() external view returns (uint96);
    function feeRecipient() external view returns (address);
    function timelock() external view returns (uint96);
    function supplyQueue(uint256) external view returns (Id);
    function withdrawQueue(uint256) external view returns (Id);
    function config(Id) external view returns (uint192 cap, uint64 withdrawRank);

    function idle() external view returns (uint256);
    function lastTotalAssets() external view returns (uint256);

    function submitTimelock(uint256 newTimelock) external;
    function acceptTimelock() external;
    function pendingTimelock() external view returns (uint192 value, uint64 submittedAt);

    function submitCap(MarketParams memory marketParams, uint256 marketCap) external;
    function acceptCap(Id id) external;
    function pendingCap(Id) external view returns (uint192 value, uint64 submittedAt);

    function submitFee(uint256 newFee) external;
    function acceptFee() external;
    function pendingFee() external view returns (uint192 value, uint64 submittedAt);

    function setIsAllocator(address newAllocator, bool newIsAllocator) external;
    function setIsRiskManager(address newRiskManager, bool newIsRiskManager) external;
    function setFeeRecipient(address newFeeRecipient) external;

    function setSupplyQueue(Id[] calldata newSupplyQueue) external;

    /// @notice Changes the order of the withdraw queue, given a permutation.
    /// @param indexes The permutation, mapping an Id's previous index in the withdraw queue to its new position in
    /// `indexes`.
    function sortWithdrawQueue(uint256[] calldata indexes) external;
    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied) external;
}
