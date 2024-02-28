// SPDX-License-Identifier: GPL-2.0-or-later
import "Range.spec";

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
        // Safe require because it is a verified invariant.
        require isTimelockInRange();
        // Safe require as it corresponds to some time very far into the future.
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
        // safe require as it is a verified invariant.
        require isPendingTimelockInRange();
        // Safe require because it is a verified invariant.
        require isTimelockInRange();
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
        // Safe require because it is a verified invariant.
        require isTimelockInRange();
        // Safe require as it corresponds to some time very far into the future.
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
        // Safe require because it is a verified invariant.
        require isTimelockInRange();
        // Safe require as it corresponds to some time very far into the future.
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
