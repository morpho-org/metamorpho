// SPDX-License-Identifier: GPL-2.0-or-later
import "Enabled.spec";

methods {
    function _.supplyShares(MetaMorphoHarness.Id id, address user) external => summarySupplyshares(id, user) expect uint256;
}

ghost lastSupplyShares(MetaMorphoHarness.Id, address) returns uint256;

function summarySupplyshares(MetaMorphoHarness.Id id, address user) returns uint256 {
    uint256 res;
    require lastSupplyShares(id, user) == res;
    return res;
}

persistent ghost uint256 lastTimestamp;

hook TIMESTAMP uint newTimestamp {
    // Safe require because timestamps are guaranteed to be increasing.
    require newTimestamp >= lastTimestamp;
    // Safe require as it corresponds to some time very far into the future.
    require newTimestamp < 2^63;
    lastTimestamp = newTimestamp;
}

// Show that nextGuardianUpdateTime does not revert.
rule nextGuardianUpdateTimeDoesNotRevert() {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;

    requireInvariant timelockInRange();
    requireInvariant pendingTimelockInRange();

    nextGuardianUpdateTime@withrevert(e);

    assert !lastReverted;
}

// Show that nextGuardianUpdateTime is increasing with time and that no change of guardian can happen before it.
rule guardianUpdateTime(env e_next, method f, calldataarg args) {
    // The environment e yields the current time.
    env e;

    requireInvariant timelockInRange();

    uint256 nextTime = nextGuardianUpdateTime(e);
    address prevGuardian = guardian();

    // Assume that the guardian is already set.
    require prevGuardian != 0;
    uint256 nextGuardianUpdateTimeBeforeInteraction = nextGuardianUpdateTime(e);
    // Increasing nextGuardianUpdateTime with no interaction;
    assert nextGuardianUpdateTimeBeforeInteraction >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that guardian cannot change.
        assert guardian() == prevGuardian;
        // Increasing nextGuardianUpdateTime with an interaction;
        assert nextGuardianUpdateTime(e_next) >= nextGuardianUpdateTimeBeforeInteraction;
    }
    assert true;
}

// Show that nextCapIncreaseTime does not revert.
rule nextCapIncreaseTimeDoesNotRevert(MetaMorphoHarness.Id id) {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;

    requireInvariant timelockInRange();
    requireInvariant pendingTimelockInRange();

    nextCapIncreaseTime@withrevert(e, id);

    assert !lastReverted;
}

// Show that nextCapIncreaseTime is increasing with time and that no increase of cap can happen before it.
rule capIncreaseTime(env e_next, method f, calldataarg args) {
    // The environment e yields the current time.
    env e;

    MetaMorphoHarness.Id id;

    requireInvariant timelockInRange();

    uint256 nextTime = nextCapIncreaseTime(e, id);
    uint184 prevCap = config_(id).cap;

    uint256 nextCapIncreaseTimeBeforeInteraction = nextCapIncreaseTime(e_next, id);
    // Increasing nextCapIncreaseTime with no interaction;
    assert nextCapIncreaseTimeBeforeInteraction >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that the cap cannot increase.
        assert config_(id).cap <= prevCap;
        // Increasing nextCapIncreaseTime with an interaction;
        assert nextCapIncreaseTime(e_next, id) >= nextCapIncreaseTimeBeforeInteraction;
    }
    assert true;
}

// Show that nextTimelockDecreaseTime does not revert.
rule nextTimelockDecreaseTimeDoesNotRevert() {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;

    requireInvariant timelockInRange();
    requireInvariant pendingTimelockInRange();

    nextTimelockDecreaseTime@withrevert(e);

    assert !lastReverted;
}

// Show that nextTimelockDecreaseTime is increasing with time and that no decrease of timelock can happen before it.
rule timelockDecreaseTime(env e_next, method f, calldataarg args) {
    // The environment e yields the current time.
    env e;

    requireInvariant timelockInRange();

    uint256 nextTime = nextTimelockDecreaseTime(e);
    uint256 prevTimelock = timelock();

    uint256 nextTimelockDecreaseTimeBeforeInteraction = nextTimelockDecreaseTime(e_next);
    // Increasing nextTimelockDecreaseTime with no interaction;
    assert nextTimelockDecreaseTimeBeforeInteraction >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that timelock cannot decrease.
        assert timelock() >= prevTimelock;
        // Increasing nextTimelockDecreaseTime with an interaction;
        assert nextTimelockDecreaseTime(e_next) >= nextTimelockDecreaseTimeBeforeInteraction;
    }
    assert true;
}

// Show that nextRemovableTime does not revert.
rule nextRemovableTimeDoesNotRevert(MetaMorphoHarness.Id id) {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;

    requireInvariant timelockInRange();
    requireInvariant pendingTimelockInRange();

    nextRemovableTime@withrevert(e, id);

    assert !lastReverted;
}

// Show that nextRemovableTime is increasing with time and that no removal can happen before it.
rule removableTime(env e_next, method f, calldataarg args) {
    // The environment e yields the current time.
    env e;
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    MetaMorphoHarness.Id id;

    requireInvariant timelockInRange();

    uint256 nextTime = nextRemovableTime(e, id);

    // Assume that the market is enabled.
    require config_(id).enabled;
    uint256 nextRemovableTimeBeforeInteraction = nextRemovableTime(e_next, id);
    // Increasing nextRemovableTime with no interaction;
    assert nextRemovableTimeBeforeInteraction >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that no forced removal happened.
        assert lastSupplyShares(id, currentContract) > 0 => config_(id).enabled;
        // Increasing nextRemovableTime with an interaction;
        assert nextRemovableTime(e_next, id) >= nextRemovableTimeBeforeInteraction;
    }
    assert true;
}
