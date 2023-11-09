// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMorpho, Id, MarketParams} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";
import {IERC20Permit} from "@openzeppelin/token/ERC20/extensions/IERC20Permit.sol";

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
    /// @notice The amount of shares to allocate.
    uint256 shares;
}

interface IMulticall {
    function multicall(bytes[] calldata) external returns (bytes[] memory);
}

interface IOwnable {
    function owner() external returns (address);
    function transferOwnership(address) external;
    function renounceOwnership() external;
    function acceptOwnership() external;
    function pendingOwner() external view returns (address);
}

/// @dev This interface is used for factorizing IMetaMorphoStaticTyping and IMetaMorpho.
/// @dev Consider using the IMetaMorpho interface instead of this one.
interface IMetaMorphoBase {
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

    function idle() external view returns (uint256);
    function lastTotalAssets() external view returns (uint256);

    function submitTimelock(uint256 newTimelock) external;
    function acceptTimelock() external;
    function revokePendingTimelock() external;

    function submitCap(MarketParams memory marketParams, uint256 supplyCap) external;
    function acceptCap(Id id) external;
    function revokePendingCap(Id id) external;

    function submitFee(uint256 newFee) external;
    function acceptFee() external;

    function submitGuardian(address newGuardian) external;
    function acceptGuardian() external;
    function revokePendingGuardian() external;

    function transferRewards(address) external;

    function setIsAllocator(address newAllocator, bool newIsAllocator) external;
    function setCurator(address newCurator) external;
    function setFeeRecipient(address newFeeRecipient) external;
    function setRewardsRecipient(address) external;

    function setSupplyQueue(Id[] calldata newSupplyQueue) external;
    function updateWithdrawQueue(uint256[] calldata indexes) external;
    function reallocate(MarketAllocation[] calldata withdrawn, MarketAllocation[] calldata supplied) external;
}

/// @dev This interface is inherited by MetaMorpho so that function signatures are checked by the compiler.
/// @dev Consider using the IMetaMorpho interface instead of this one.
interface IMetaMorphoStaticTyping is IMetaMorphoBase {
    function config(Id) external view returns (uint192 cap, uint64 withdrawRank);
    function pendingGuardian() external view returns (address guardian, uint64 submittedAt);
    function pendingCap(Id) external view returns (uint192 value, uint64 submittedAt);
    function pendingTimelock() external view returns (uint192 value, uint64 submittedAt);
    function pendingFee() external view returns (uint192 value, uint64 submittedAt);
}

/// @title IMetaMorpho
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @dev Use this interface for MetaMorpho to have access to all the functions with the appropriate function signatures.
interface IMetaMorpho is IMetaMorphoBase, IERC4626, IERC20Permit, IOwnable, IMulticall {
    function config(Id) external view returns (MarketConfig memory);
    function pendingGuardian() external view returns (PendingAddress memory);
    function pendingCap(Id) external view returns (PendingUint192 memory);
    function pendingTimelock() external view returns (PendingUint192 memory);
    function pendingFee() external view returns (PendingUint192 memory);
}
