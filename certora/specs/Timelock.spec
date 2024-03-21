// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

methods {
    function _.supplyShares(MetaMorphoHarness.Id id, address user) external => summarySupplyshares(id, user) expect uint256;
}

ghost lastSupplyShares(MetaMorphoHarness.Id, address) returns uint256;

function summarySupplyshares(MetaMorphoHarness.Id id, address user) returns uint256 {
    uint256 res;
    require lastSupplyShares(id, user) == res;
    return res;
}

// Show that nextGuardianUpdateTime does not revert.
rule nextGuardianUpdateTimeDoesNotRevert() {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require because it is a verified invariant.
    require isPendingTimelockInRange();

    nextGuardianUpdateTime@withrevert(e);

    assert !lastReverted;
}

// Show that nextGuardianUpdateTime is increasing with time and that no change of guardian can happen before it.
rule guardianUpdateTime(env e_next, method f, calldataarg args) {
    // The environment e yields the current time.
    env e;
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();

    uint256 nextTime = nextGuardianUpdateTime(e);
    address prevGuardian = guardian();

    // Assume that the guardian is already set.
    require prevGuardian != 0;
    // Sane assumption on the current time, as any following transaction should happen after it.
    require e_next.block.timestamp >= e.block.timestamp;
    // Increasing nextGuardianUpdateTime with no interaction;
    assert nextGuardianUpdateTime(e_next) >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that guardian cannot change.
        assert guardian() == prevGuardian;
        // Increasing nextGuardianUpdateTime with an interaction;
        assert nextGuardianUpdateTime(e_next) >= nextTime;
    }
    assert true;
}

// Show that nextCapIncreaseTime does not revert.
rule nextCapIncreaseTimeDoesNotRevert(MetaMorphoHarness.Id id) {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require because it is a verified invariant.
    require isPendingTimelockInRange();

    nextCapIncreaseTime@withrevert(e, id);

    assert !lastReverted;
}

// Show that nextCapIncreaseTime is increasing with time and that no increase of cap can happen before it.
rule capIncreaseTime(env e_next, method f, calldataarg args) {
    // The environment e yields the current time.
    env e;
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    MetaMorphoHarness.Id id;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();

    uint256 nextTime = nextCapIncreaseTime(e, id);
    uint184 prevCap = config_(id).cap;

    // Sane assumption on the current time, as any following transaction should happen after it.
    require e_next.block.timestamp >= e.block.timestamp;
    // Increasing nextCapIncreaseTime with no interaction;
    assert nextCapIncreaseTime(e_next, id) >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that cap cannot increase.
        assert config_(id).cap <= prevCap;
        // Increasing nextCapIncreaseTime with an interaction;
        assert nextCapIncreaseTime(e_next, id) >= nextTime;
    }
    assert true;
}

// Show that nextTimelockDecreaseTime does not revert.
rule nextTimelockDecreaseTimeDoesNotRevert() {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require because it is a verified invariant.
    require isPendingTimelockInRange();

    nextTimelockDecreaseTime@withrevert(e);

    assert !lastReverted;
}

// Show that nextTimelockDecreaseTime is increasing with time and that no decrease of timelock can happen before it.
rule timelockDecreaseTime(env e_next, method f, calldataarg args) {
    // The environment e yields the current time.
    env e;
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();

    uint256 nextTime = nextTimelockDecreaseTime(e);
    uint256 prevTimelock = timelock();

    // Sane assumption on the current time, as any following transaction should happen after it.
    require e_next.block.timestamp >= e.block.timestamp;
    // Increasing nextTimelockDecreaseTime with no interaction;
    assert nextTimelockDecreaseTime(e_next) >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that timelock cannot decrease.
        assert timelock() >= prevTimelock;
        // Increasing nextTimelockDecreaseTime with an interaction;
        assert nextTimelockDecreaseTime(e_next) >= nextTime;
    }
    assert true;
}

// Show that nextRemovableTime does not revert.
rule nextRemovableTimeDoesNotRevert(MetaMorphoHarness.Id id) {
    // The environment e yields the current time.
    env e;
    require e.msg.value == 0;
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require because it is a verified invariant.
    require isPendingTimelockInRange();

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

    // Safe require because it is a verified invariant.
    require isTimelockInRange();

    uint256 nextTime = nextRemovableTime(e, id);

    // Assume that the market is enabled.
    require config_(id).enabled;
    // Sane assumption on the current time, as any following transaction should happen after it.
    require e_next.block.timestamp >= e.block.timestamp;
    // Increasing nextRemovableTime with no interaction;
    assert nextRemovableTime(e_next, id) >= nextTime;

    f(e_next, args);

    if (e_next.block.timestamp < nextTime)  {
        // Check that no forced removal happened.
        assert lastSupplyShares(id, currentContract) > 0 => config_(id).enabled;
        // Increasing nextRemovableTime with an interaction;
        assert nextRemovableTime(e_next, id) >= nextTime;
    }
    assert true;
}
