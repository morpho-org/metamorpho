// SPDX-License-Identifier: GPL-2.0-or-later
import "Enabled.spec";

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
// This invariant is useful to conclude that markets that are not enabled cannot be interacted with (notably for reallocate).
invariant supplyCapIsEnabled(MetaMorphoHarness.Id id)
    hasSupplyCapIsEnabled(id);
// Check that a market with a positive cap cannot be marked for removal.
function hasSupplyCapIsNotMarkedForRemoval(MetaMorphoHarness.Id id) returns bool {
    uint192 supplyCap;
    uint64 removableAt;
    supplyCap, _, removableAt = config(id);

    return supplyCap > 0 => removableAt == 0;
}

invariant supplyCapIsNotMarkedForRemoval(MetaMorphoHarness.Id id)
    hasSupplyCapIsNotMarkedForRemoval(id);

// Check that a market with a pending cap cannot be marked for removal.
function hasPendingCapIsNotMarkedForRemoval(MetaMorphoHarness.Id id) returns bool {
    uint64 pendingAt;
    _, pendingAt = pendingCap(id);
    uint64 removableAt;
    _, _, removableAt = config(id);

    return pendingAt > 0 => removableAt == 0;
}

invariant pendingCapIsNotMarkedForRemoval(MetaMorphoHarness.Id id)
    hasPendingCapIsNotMarkedForRemoval(id);
