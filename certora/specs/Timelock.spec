// SPDX-License-Identifier: GPL-2.0-or-later
import "PendingValues.spec";

function min(uint256 a, uint256 b) returns(uint256) {
    return a < b ? a : b;
}

function max(uint256 a, uint256 b) returns(uint256) {
    return a < b ? b : a;
}

function pendingGuardianLockedTime(env e) returns(uint256) {
    uint256 changeableAt = e.block.timestamp + timelock();
    uint256 pendingValidAt = pendingGuardian_().validAt;

    if(pendingValidAt > 0) {
        changeableAt = min(changeableAt, pendingValidAt);
    }

    MetaMorphoHarness.PendingUint192 pendingTimelock = pendingTimelock_();
    if(pendingTimelock.validAt > 0) {
        uint256 timestampNewTimelock = max(e.block.timestamp, pendingTimelock.validAt);
        changeableAt = min(changeableAt, timestampNewTimelock + pendingTimelock.value);
    }

    return changeableAt;
}

rule changeableAt(env e, method f, calldataarg args) {
    env e_start;
    uint256 changeableAt = pendingGuardianLockedTime(e_start);
    address initialGuardian = guardian();

    require(e.block.timestamp < changeableAt);
    f(e, args);

    assert guardian() == initialGuardian;
}
