// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMorpho, Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";

struct MarketConfig {
    /// @notice The maximum amount of assets that can be allocated to the market.
    uint192 cap;
    /// @notice The rank of the market in the withdraw queue.
    uint64 withdrawRank;
}

struct PendingUint192 {
    /// @notice The pending value to set.
    uint192 value;
    /// @notice The timestamp at which the value was submitted.
    uint64 submittedAt;
}

struct PendingAddress {
    /// @notice The pending value to set.
    address value;
    /// @notice The timestamp at which the value was submitted.
    uint64 submittedAt;
}

/// @dev Either `assets` or `shares` should be zero.
struct MarketAllocation {
    /// @notice The market to allocate.
    MarketParams marketParams;
    /// @notice The amount of assets to allocate.
    uint256 assets;
}

interface IMetaMorpho is IERC4626 {
    function MORPHO() external view returns (IMorpho);

    function curator() external view returns (address);
    function isAllocator(address target) external view returns (bool);
    function guardian() external view returns (address);

    function fee() external view returns (uint96);
    function feeRecipient() external view returns (address);
    function rewardsRecipient() external view returns (address);
    function timelock() external view returns (uint256);
    function supplyQueue(uint256) external view returns (Id);
    function supplyQueueLength() external view returns (uint256);
    function withdrawQueue(uint256) external view returns (Id);
    function withdrawQueueLength() external view returns (uint256);
    function config(Id) external view returns (uint192 cap, uint64 withdrawRank);

    function idle() external view returns (uint256);
    function lastTotalAssets() external view returns (uint256);

    function submitTimelock(uint256 newTimelock) external;
    function acceptTimelock() external;
    function revokePendingTimelock() external;
    function pendingTimelock() external view returns (uint192 value, uint64 submittedAt);

    function submitCap(MarketParams memory marketParams, uint256 supplyCap) external;
    function acceptCap(Id id) external;
    function revokePendingCap(Id id) external;
    function pendingCap(Id) external view returns (uint192 value, uint64 submittedAt);

    function submitFee(uint256 newFee) external;
    function acceptFee() external;
    function pendingFee() external view returns (uint192 value, uint64 submittedAt);

    function submitGuardian(address newGuardian) external;
    function acceptGuardian() external;
    function revokePendingGuardian() external;
    function pendingGuardian() external view returns (address guardian, uint64 submittedAt);

    function transferRewards(address) external;

    function setIsAllocator(address newAllocator, bool newIsAllocator) external;
    function setCurator(address newCurator) external;
    function setFeeRecipient(address newFeeRecipient) external;
    function setRewardsRecipient(address) external;

    function setSupplyQueue(Id[] calldata newSupplyQueue) external;
    function updateWithdrawQueue(uint256[] calldata indexes) external;
    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied) external;
}

interface IPending {
    function pendingTimelock() external view returns (PendingUint192 memory);
    function pendingCap(Id) external view returns (PendingUint192 memory);
    function pendingGuardian() external view returns (PendingAddress memory);
}
