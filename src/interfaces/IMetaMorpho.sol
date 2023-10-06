// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMorpho, Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

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
    uint96 submittedAt;
}

/// @dev Either `assets` or `shares` should be zero.
struct MarketAllocation {
    /// @notice The market to allocate.
    MarketParams marketParams;
    /// @notice The amount of assets to allocate.
    uint256 assets;
    /// @notice The amount of shares to allocate.
    uint256 shares;
}

interface IMetaMorpho is IERC4626 {
    function MORPHO() external view returns (IMorpho);

    function initialize(
        address owner,
        uint256 initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) external;

    function riskManager() external view returns (address);
    function isAllocator(address target) external view returns (bool);
    function guardian() external view returns (address);

    function fee() external view returns (uint96);
    function feeRecipient() external view returns (address);
    function rewardsDistributor() external view returns (address);
    function timelock() external view returns (uint256);
    function supplyQueue(uint256) external view returns (Id);
    function withdrawQueue(uint256) external view returns (Id);
    function config(Id) external view returns (uint192 cap, uint64 withdrawRank);

    function idle() external view returns (uint256);
    function lastTotalAssets() external view returns (uint256);

    function submitTimelock(uint256 newTimelock) external;
    function acceptTimelock() external;
    function revokeTimelock() external;
    function pendingTimelock() external view returns (uint192 value, uint64 submittedAt);

    function submitCap(MarketParams memory marketParams, uint256 marketCap) external;
    function acceptCap(Id id) external;
    function revokeCap(Id id) external;
    function pendingCap(Id) external view returns (uint192 value, uint64 submittedAt);

    function submitFee(uint256 newFee) external;
    function acceptFee() external;
    function pendingFee() external view returns (uint192 value, uint64 submittedAt);

    function submitGuardian(address newGuardian) external;
    function acceptGuardian() external;
    function revokeGuardian() external;
    function pendingGuardian() external view returns (address guardian, uint96 submittedAt);

    function setIsAllocator(address newAllocator, bool newIsAllocator) external;
    function setRiskManager(address newRiskManager) external;
    function setFeeRecipient(address newFeeRecipient) external;

    function setSupplyQueue(Id[] calldata newSupplyQueue) external;
    function sortWithdrawQueue(uint256[] calldata indexes) external;
    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied) external;
}
