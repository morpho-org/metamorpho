// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

// Show that nextGuardianUpdateTime does not revert.
rule nextGuardianUpdateTimeDoesNotRevert() {
    // The environment ec yields the current time.
    env ec;
    require ec.msg.value == 0;
    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require because it is a verified invariant.
    require isPendingTimelockInRange();

    nextGuardianUpdateTime@withrevert(ec);

    assert !lastReverted;
}

// Show that nextGuardianUpdateTime is increasing and that no change of guardian can happen before it.
rule guardianUpdateTime(env e, method f, calldataarg args) {
    // The environment ec yields the current time.
    env ec;
    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();

    uint256 nextTime = nextGuardianUpdateTime(ec);
    address prevGuardian = guardian();

    // Assume that the guardian is already set.
    require prevGuardian != 0;
    // Sane assumption on the current time, as any following transaction should happen after it.
    require e.block.timestamp >= ec.block.timestamp;
    // Increasing nextGuardianUpdateTime with no interaction;
    assert nextGuardianUpdateTime(e) >= nextTime;

    f(e, args);

    if (e.block.timestamp < nextTime)  {
        assert guardian() == prevGuardian;
        // Increasing nextGuardianUpdateTime with an interaction;
        assert nextGuardianUpdateTime(e) >= nextTime;
    }
    assert true;
}

// Show that nextCapIncreaseTime does not revert.
rule nextCapIncreaseTimeDoesNotRevert(MetaMorphoHarness.Id id) {
    // The environment ec yields the current time.
    env ec;
    require ec.msg.value == 0;
    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require because it is a verified invariant.
    require isPendingTimelockInRange();

    nextCapIncreaseTime@withrevert(ec, id);

    assert !lastReverted;
}

// Show that nextCapIncreaseTime is increasing and that no increase of cap can happen before it.
rule capIncreaseTime(env e, method f, calldataarg args) {
    // The environment ec yields the current time.
    env ec;
    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;

    MetaMorphoHarness.Id id;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();

    uint256 nextTime = nextCapIncreaseTime(ec, id);
    uint184 prevCap = config_(id).cap;

    // Sane assumption on the current time, as any following transaction should happen after it.
    require e.block.timestamp >= ec.block.timestamp;
    // Increasing nextCapIncreaseTime with no interaction;
    assert nextCapIncreaseTime(e, id) >= nextTime;

    f(e, args);

    if (e.block.timestamp < nextTime)  {
        assert config_(id).cap <= prevCap;
        // Increasing nextCapIncreaseTime with an interaction;
        assert nextCapIncreaseTime(e, id) >= nextTime;
    }
    assert true;
}

// Show that nextTimelockDecreaseTime does not revert.
rule nextTimelockDecreaseTimeDoesNotRevert() {
    // The environment ec yields the current time.
    env ec;
    require ec.msg.value == 0;
    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require because it is a verified invariant.
    require isPendingTimelockInRange();

    nextTimelockDecreaseTime@withrevert(ec);

    assert !lastReverted;
}

// Show that nextTimelockDecreaseTime is increasing and that no decrease of timelock can happen before it.
rule timelockDecreaseTime(env e, method f, calldataarg args) {
    // The environment ec yields the current time.
    env ec;
    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();

    uint256 nextTime = nextTimelockDecreaseTime(ec);
    uint184 prevTimelock = timelock();

    // Sane assumption on the current time, as any following transaction should happen after it.
    require e.block.timestamp >= ec.block.timestamp;
    // Increasing nextTimelockDecreaseTime with no interaction;
    assert nextTimelockDecreaseTime(e) >= nextTime;

    f(e, args);

    if (e.block.timestamp < nextTime)  {
        assert timelock() >= prevTimelock;
        // Increasing nextTimelockDecreaseTime with an interaction;
        assert nextTimelockDecreaseTime(e) >= nextTime;
    }
    assert true;
}

// Show that nextRemovableTime does not revert.
rule nextRemovableTimeDoesNotRevert(MetaMorphoHarness.Id id) {
    // The environment ec yields the current time.
    env ec;
    require ec.msg.value == 0;
    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require because it is a verified invariant.
    require isPendingTimelockInRange();

    nextRemovableTime@withrevert(ec, id);

    assert !lastReverted;
}

// Show that nextRemovableTime is increasing and that no removal can happen before it.
rule removableTime(env e, method f, calldataarg args) {
    // The environment ec yields the current time.
    env ec;
    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;

    MetaMorphoHarness.Id id;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();

    uint256 nextTime = nextRemovableTime(ec, id);

    // Assume that the market is enabled.
    require config_(id).enabled;
    // Sane assumption on the current time, as any following transaction should happen after it.
    require e.block.timestamp >= ec.block.timestamp;
    // Increasing nextRemovableTime with no interaction;
    assert nextRemovableTime(e, id) >= nextTime;

    f(e, args);

    if (e.block.timestamp < nextTime)  {
        assert config_(id).enabled;
        // Increasing nextRemovableTime with an interaction;
        assert nextRemovableTime(e, id) >= nextTime;
    }
    assert true;
}
