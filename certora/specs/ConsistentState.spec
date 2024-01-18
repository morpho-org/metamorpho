// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function pendingTimelock() external returns(uint192, uint64) envfree;
    function timelock() external returns(uint256) envfree;
    function guardian() external returns(address) envfree;
    function pendingGuardian() external returns(address, uint64) envfree;
    function pendingCap(MetaMorphoHarness.Id) external returns(uint192, uint64) envfree;
    function config(MetaMorphoHarness.Id) external returns(uint184, bool, uint64) envfree;
    function supplyQueueLength() external returns(uint256) envfree;
    function withdrawQueueLength() external returns(uint256) envfree;
    function withdrawQueue(uint256) external returns(MetaMorphoHarness.Id) envfree;
    function withdrawRank(MetaMorphoHarness.Id) external returns(uint256) envfree;
    function deletedBy(MetaMorphoHarness.Id) external returns(uint256) envfree;
    function fee() external returns(uint96) envfree;
    function feeRecipient() external returns(address) envfree;

    function minTimelock() external returns(uint256) envfree;
    function maxTimelock() external returns(uint256) envfree;
    function maxQueueLength() external returns(uint256) envfree;
    function maxFee() external returns(uint256) envfree;
}

// Check that the fee cannot go over the max fee.
invariant feeInRange()
    assert_uint256(fee()) <= maxFee();

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

// Check that the supply queue length cannot go over the max queue length.
invariant supplyQueueLengthInRange()
    supplyQueueLength() <= maxQueueLength();

// Check that the withdraw queue length cannot go over the max queue length.
invariant withdrawQueueLengthInRange()
    withdrawQueueLength() <= maxQueueLength();

function hasNoBadPendingTimelock() returns bool {
    uint192 pendingValue;
    uint64 validAt;
    pendingValue, validAt = pendingTimelock();

    return validAt == 0 <=> pendingValue == 0;
}

// Check that having no pending timelock value is equivalent to having its valid timestamp at 0.
invariant noBadPendingTimelock()
    hasNoBadPendingTimelock()
{
    preserved with (env e) {
        requireInvariant timelockInRange();
        // Safe require as it corresponds to year 2262.
        require e.block.timestamp < 2^63;
    }
}

function isSmallerPendingTimelock() returns bool {
    uint192 pendingValue;
    pendingValue, _ = pendingTimelock();

    return assert_uint256(pendingValue) < timelock();
}

// Check that the pending timelock value is always strictly smaller than the current timelock value.
invariant smallerPendingTimelock()
    isSmallerPendingTimelock()
{
    preserved {
        requireInvariant pendingTimelockInRange();
        requireInvariant timelockInRange();
    }
}

function hasNoBadPendingCap(MetaMorphoHarness.Id id) returns bool {
    uint192 pendingValue;
    uint64 validAt;
    pendingValue, validAt = pendingCap(id);

    return validAt == 0 <=> pendingValue == 0;
}

// Check that having no pending cap value is equivalent to having its valid timestamp at 0.
invariant noBadPendingCap(MetaMorphoHarness.Id id)
    hasNoBadPendingCap(id)
{
    preserved with (env e) {
        requireInvariant timelockInRange();
        // Safe require as it corresponds to year 2262.
        require e.block.timestamp < 2^63;
    }
}

function isGreaterPendingCap(MetaMorphoHarness.Id id) returns bool {
    uint192 pendingValue;
    pendingValue, _ = pendingCap(id);
    uint192 currentValue;
    currentValue, _, _ = config(id);

    return pendingValue != 0 => assert_uint256(pendingValue) > assert_uint256(currentValue);
}

// Check that the pending cap value is either 0 or strictly greater than the current timelock value.
invariant greaterPendingCap(MetaMorphoHarness.Id id)
    isGreaterPendingCap(id);

function hasNoBadPendingGuardian() returns bool {
    address pendingValue;
    uint64 validAt;
    pendingValue, validAt = pendingGuardian();

    // Notice that address(0) is a valid value for a new guardian.
    return validAt == 0 => pendingValue == 0;
}

// Check that when its valid timestamp at 0 the pending guardian is the zero address.
invariant noBadPendingGuardian()
    hasNoBadPendingGuardian()
{
    preserved with (env e) {
        requireInvariant timelockInRange();
        // Safe require as it corresponds to year 2262.
        require e.block.timestamp < 2^63;
    }
}

function isDifferentPendingGuardian() returns bool {
    address pendingValue;
    pendingValue, _ = pendingGuardian();

    return pendingValue != 0 => pendingValue != guardian();
}

// Check that the pending guardian is either the zero address or it is different from the current guardian.
invariant differentPendingGuardian()
    isDifferentPendingGuardian();

// Check that fee cannot accrue to an unset fee recipient.
invariant noFeeToUnsetFeeRecipient()
    feeRecipient() == 0 => fee() == 0;

function hasSupplyCapIsEnabled(MetaMorphoHarness.Id id) returns bool {
    uint192 supplyCap;
    bool enabled;
    supplyCap, enabled, _ = config(id);

    return supplyCap > 0 => enabled;
}

// Check that having a positive supply cap implies that the market is enabled.
// This invariant is useful to conclude that market that are not enabled cannot be interacted with (notably for reallocate).
invariant supplyCapIsEnabled(MetaMorphoHarness.Id id)
    hasSupplyCapIsEnabled(id);

function hasDistinctIdentifiers(uint256 i, uint256 j) returns bool {
    return i != j => withdrawQueue(i) != withdrawQueue(j);
}

// Check that there are no duplicate markets in the withdraw queue.
invariant distinctIdentifiers(uint256 i, uint256 j)
    hasDistinctIdentifiers(i, j)
{
    preserved updateWithdrawQueue(uint256[] indexes) with (env e) {
        require hasDistinctIdentifiers(indexes[i], indexes[j]);
    }
}

function isInWithdrawQueueIsEnabled(uint256 i) returns bool {
    if(i >= withdrawQueueLength()) return true;

    MetaMorphoHarness.Id id = withdrawQueue(i);
    bool enabled;
    _, enabled, _ = config(id);

    return enabled;
}

// Check that markets in the withdraw queue are enabled.
invariant inWithdrawQueueIsEnabled(uint256 i)
    isInWithdrawQueueIsEnabled(i)
filtered {
    f -> f.selector != sig:updateWithdrawQueue(uint256[]).selector
}

rule inWithdrawQueueIsEnabledPreservedUpdateWithdrawQueue(env e, uint256 i, uint256[] indexes) {
    uint256 j;
    require isInWithdrawQueueIsEnabled(indexes[i]);

    requireInvariant distinctIdentifiers(indexes[i], j);

    updateWithdrawQueue(e, indexes);

    MetaMorphoHarness.Id id = withdrawQueue(i);
    // Safe require because j is not otherwise constrained.
    // The ghost variable deletedBy is useful to make sure that markets are not permuted and deleted at the same time in updateWithdrawQueue.
    require j == deletedBy(id);

    assert isInWithdrawQueueIsEnabled(i);
}

function isWithdrawRankCorrect(MetaMorphoHarness.Id id) returns bool {
    uint256 rank = withdrawRank(id);

    if (rank == 0) return true;

    return withdrawQueue(assert_uint256(rank - 1)) == id;
}

// Checks that the withdraw rank of a market is given by the withdrawRank ghost variable.
invariant withdrawRankCorrect(MetaMorphoHarness.Id id)
    isWithdrawRankCorrect(id);

function isEnabledHasPositiveRank(MetaMorphoHarness.Id id) returns bool {
    bool enabled;
    _, enabled, _ = config(id);

    uint256 rank = withdrawRank(id);

    return enabled => rank > 0;
}

// Checks that enabled markets have a positive withdraw rank, according to the withdrawRank ghost variable.
invariant enabledHasPositiveRank(MetaMorphoHarness.Id id)
    isEnabledHasPositiveRank(id);

// Check that enabled markets are in the withdraw queue.
rule enabledIsInWithdrawQueue(MetaMorphoHarness.Id id) {
    bool enabled;
    _, enabled, _ = config(id);

    require enabled;

    requireInvariant enabledHasPositiveRank(id);
    requireInvariant withdrawRankCorrect(id);

    uint256 witness = assert_uint256(withdrawRank(id) - 1);
    assert withdrawQueue(witness) == id;
}
