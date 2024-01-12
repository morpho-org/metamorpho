// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function pendingTimelock() external returns(uint192, uint64) envfree;
    function timelock() external returns (uint256) envfree;
    function guardian() external returns (address) envfree;
    function pendingGuardian() external returns(address, uint64) envfree;
    function pendingCap(MetaMorphoHarness.Id) external returns(uint192, uint64) envfree;
    function config(MetaMorphoHarness.Id) external returns(uint184, bool, uint64) envfree;
    function supplyQueueLength() external returns(uint256) envfree;
    function withdrawQueueLength() external returns(uint256) envfree;
    function withdrawQueue(uint256) external returns(MetaMorphoHarness.Id) envfree;
    function withdrawRank(MetaMorphoHarness.Id) external returns(uint256) envfree;
    function fee() external returns (uint96) envfree;

    function minTimelock() external returns (uint256) envfree;
    function maxTimelock() external returns (uint256) envfree;
    function maxQueueLength() external returns (uint256) envfree;
    function maxFee() external returns (uint256) envfree;
}

invariant feeInRange()
    assert_uint256(fee()) <= maxFee();

function isPendingTimelockInRange() returns bool {
    uint192 value;
    uint64 validAt;
    value, validAt = pendingTimelock();

    return validAt != 0 => assert_uint256(value) <= maxTimelock() && assert_uint256(value) >= minTimelock();
}

invariant pendingTimelockInRange()
    isPendingTimelockInRange();

invariant timelockInRange()
    timelock() <= maxTimelock() && timelock() >= minTimelock()
{
    preserved {
        requireInvariant pendingTimelockInRange();
    }
}

invariant supplyQueueLengthInRange()
    supplyQueueLength() <= maxQueueLength();

invariant withdrawQueueLengthInRange()
    withdrawQueueLength() <= maxQueueLength();

function hasNoBadPendingTimelock() returns bool {
    uint192 pendingValue;
    uint64 validAt;
    pendingValue, validAt = pendingTimelock();

    return validAt == 0 <=> pendingValue == 0;
}

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

invariant greaterPendingCap(MetaMorphoHarness.Id id)
    isGreaterPendingCap(id);

function hasNoBadPendingGuardian() returns bool {
    address pendingValue;
    uint64 validAt;
    pendingValue, validAt = pendingGuardian();

    // Notice that address(0) is a valid value for a new guardian.
    return validAt == 0 => pendingValue == 0;
}

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

invariant differentPendingGuardian()
    isDifferentPendingGuardian();

function isInWithdrawQueueIsEnabled(uint256 i) returns bool {
    if(i >= withdrawQueueLength()) return true;

    MetaMorphoHarness.Id id = withdrawQueue(i);
    bool enabled;
    _, enabled, _ = config(id);

    return enabled;
}

invariant inWithdrawQueueIsEnabled(uint256 i)
    isInWithdrawQueueIsEnabled(i)
filtered {
    f -> f.selector != sig:updateWithdrawQueue(uint256[]).selector
}

rule inWithdrawQueueIsEnabledPreservedupdateWithdrawQueue(env e, uint256 i, uint256[] indexes) {
    uint j;

    require isInWithdrawQueueIsEnabled(j);

    updateWithdrawQueue(e, indexes);

    MetaMorphoHarness.Id id = withdrawQueue(i);
    require j == withdrawRank(id);

    assert isInWithdrawQueueIsEnabled(i);
}
