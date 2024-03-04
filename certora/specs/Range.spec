// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function MORPHO() external returns(address) envfree;
    function asset() external returns(address) envfree;
    function pendingTimelock() external returns(uint192, uint64) envfree;
    function timelock() external returns(uint256) envfree;
    function guardian() external returns(address) envfree;
    function pendingGuardian() external returns(address, uint64) envfree;
    function pendingCap(MetaMorphoHarness.Id) external returns(uint192, uint64) envfree;
    function config(MetaMorphoHarness.Id) external returns(uint184, bool, uint64) envfree;
    function supplyQueueLength() external returns(uint256) envfree;
    function supplyQueue(uint256) external returns(MetaMorphoHarness.Id) envfree;
    function withdrawQueueLength() external returns(uint256) envfree;
    function withdrawQueue(uint256) external returns(MetaMorphoHarness.Id) envfree;
    function withdrawRank(MetaMorphoHarness.Id) external returns(uint256) envfree;
    function deletedAt(MetaMorphoHarness.Id) external returns(uint256) envfree;
    function fee() external returns(uint96) envfree;
    function feeRecipient() external returns(address) envfree;
    function owner() external returns(address) envfree;
    function curator() external returns(address) envfree;
    function isAllocator(address) external returns(bool) envfree;
    function skimRecipient() external returns(address) envfree;

    function minTimelock() external returns(uint256) envfree;
    function maxTimelock() external returns(uint256) envfree;
    function maxQueueLength() external returns(uint256) envfree;
    function maxFee() external returns(uint256) envfree;
}

function isPendingTimelockInRange() returns bool {
    uint192 value;
    uint64 validAt;
    value, validAt = pendingTimelock();

    return validAt != 0 => assert_uint256(value) <= maxTimelock() && assert_uint256(value) >= minTimelock();
}

// Check that the pending timelock is bounded by the min timelock and the max timelock.
invariant pendingTimelockInRange()
    isPendingTimelockInRange();

function isTimelockInRange() returns bool {
    return timelock() <= maxTimelock() && timelock() >= minTimelock();
}

// Check that the timelock is bounded by the min timelock and the max timelock.
invariant timelockInRange()
    isTimelockInRange()
{
    preserved {
        requireInvariant pendingTimelockInRange();
    }
}

// Check that the fee cannot go over the max fee.
invariant feeInRange()
    assert_uint256(fee()) <= maxFee();

// Check that the supply queue length cannot go over the max queue length.
invariant supplyQueueLengthInRange()
    supplyQueueLength() <= maxQueueLength();

// Check that the withdraw queue length cannot go over the max queue length.
invariant withdrawQueueLengthInRange()
    withdrawQueueLength() <= maxQueueLength();
