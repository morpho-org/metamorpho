// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

rule guardianUpdateTime(uint256 currentTime, env e, method f, calldataarg args) {
    // Safe require as it corresponds to some time very far into the future.
    require currentTime < 2^63;
    // Safe require because it is a verified invariant.
    require isTimelockInRange();

    uint256 nextTime = nextGuardianUpdateTime(currentTime);
    address prevGuardian = guardian();

    // Assume that the guardian is already set.
    require prevGuardian != 0;
    // Sane assumption on the current time.
    require e.block.timestamp >= currentTime;
    // Increasing nextGuardianUpdateTime with no interaction;
    assert nextGuardianUpdateTime(e.block.timestamp) >= nextTime;

    f(e, args);

    if (guardian() != prevGuardian) {
        assert e.block.timestamp >= nextTime;
    }
    if (e.block.timestamp < nextTime)  {
        assert guardian() == prevGuardian;
        // Increasing nextGuardianUpdateTime with an interaction;
        assert nextGuardianUpdateTime(e.block.timestamp) >= nextTime;
    }
    assert true;
}
