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

// Show that nextCapUpdateTime does not revert.
rule nextCapUpdateTimeDoesNotRevert(MetaMorphoHarness.Id id) {
    // The environment ec yields the current time.
    env ec;

    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;
    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require because it is a verified invariant.
    require isPendingTimelockInRange();

    nextCapUpdateTime@withrevert(ec, id);

    assert !lastReverted;
}

// Show that nextCapUpdateTime is increasing and that no change of cap can happen before it.
rule capUpdateTime(env e, method f, calldataarg args) {
    // The environment ec yields the current time.
    env ec;
    require ec.msg.value == 0;
    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;

    MetaMorphoHarness.Id id;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();

    uint256 nextTime = nextCapUpdateTime(ec, id);
    uint184 prevCap = config_(id).cap;

    // Assume that the cap is already set.
    require prevCap != 0;
    // Sane assumption on the current time, as any following transaction should happen after it.
    require e.block.timestamp >= ec.block.timestamp;
    // Increasing nextCapUpdateTime with no interaction;
    assert nextCapUpdateTime(e, id) >= nextTime;

    f(e, args);

    if (e.block.timestamp < nextTime)  {
        assert config_(id).cap == prevCap;
        // Increasing nextCapUpdateTime with an interaction;
        assert nextCapUpdateTime(e, id) >= nextTime;
    }
    assert true;
}

// Show that nextTimelockUpdateTime does not revert.
rule nextTimelockUpdateTimeDoesNotRevert() {
    // The environment ec yields the current time.
    env ec;
    require ec.msg.value == 0;
    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;

    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require because it is a verified invariant.
    require isPendingTimelockInRange();

    nextTimelockUpdateTime@withrevert(ec);

    assert !lastReverted;
}

// Show that nextTimelockUpdateTime is increasing and that no change of timelock can happen before it.
rule timelockUpdateTime(env e, method f, calldataarg args) {
    // The environment ec yields the current time.
    env ec;

    // Safe require as it corresponds to some time very far into the future.
    require ec.block.timestamp < 2^63;
    // Safe require because it is a verified invariant.
    require isTimelockInRange();

    uint256 nextTime = nextTimelockUpdateTime(ec);
    uint184 prevTimelock = timelock();

    // Assume that the Timelock is already set.
    require prevTimelock != 0;
    // Sane assumption on the current time, as any following transaction should happen after it.
    require e.block.timestamp >= ec.block.timestamp;
    // Increasing nextTimelockUpdateTime with no interaction;
    assert nextTimelockUpdateTime(e) >= nextTime;

    f(e, args);

    if (e.block.timestamp < nextTime)  {
        assert timelock() == prevTimelock;
        // Increasing nextTimelockUpdateTime with an interaction;
        assert nextTimelockUpdateTime(e) >= nextTime;
    }
    assert true;
}
