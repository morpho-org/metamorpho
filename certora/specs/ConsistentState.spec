// SPDX-License-Identifier: GPL-2.0-or-later
import "Enabled.spec";

using MorphoHarness as Morpho;

methods {
    function Morpho.libId(MorphoHarness.MarketParams) external returns(MorphoHarness.Id) envfree;
    function Morpho.lastUpdate(MorphoHarness.Id) external returns(uint256) envfree;
}

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

function hasSupplyCapHasConsistentAsset(MetaMorphoHarness.MarketParams marketParams) returns bool {
    MetaMorphoHarness.Id id = Morpho.libId(marketParams);

    uint192 supplyCap;
    supplyCap, _, _ = config(id);

    return supplyCap > 0 => marketParams.loanToken == asset();
}

// Check that haping a positive cap implies that the loan asset is the asset of the vault.
invariant supplyCapHasConsistentAsset(MetaMorphoHarness.MarketParams marketParams)
    hasSupplyCapHasConsistentAsset(marketParams);

function hasSupplyCapIsNotMarkedForRemoval(MetaMorphoHarness.Id id) returns bool {
    uint192 supplyCap;
    uint64 removableAt;
    supplyCap, _, removableAt = config(id);

    return supplyCap > 0 => removableAt == 0;
}

// Check that a market with a positive cap cannot be marked for removal.
invariant supplyCapIsNotMarkedForRemoval(MetaMorphoHarness.Id id)
    hasSupplyCapIsNotMarkedForRemoval(id);

function hasPendingCapIsNotMarkedForRemoval(MetaMorphoHarness.Id id) returns bool {
    uint64 pendingAt;
    _, pendingAt = pendingCap(id);
    uint64 removableAt;
    _, _, removableAt = config(id);

    return pendingAt > 0 => removableAt == 0;
}

// Check that a market with a pending cap cannot be marked for removal.
invariant pendingCapIsNotMarkedForRemoval(MetaMorphoHarness.Id id)
    hasPendingCapIsNotMarkedForRemoval(id);
