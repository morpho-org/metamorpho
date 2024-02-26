// SPDX-License-Identifier: GPL-2.0-or-later
import "PendingValues.spec";

function hasDistinctIdentifiers(uint256 i, uint256 j) returns bool {
    return i != j => withdrawQueue(i) != withdrawQueue(j);
}

// Check that there are no duplicate markets in the withdraw queue.
invariant distinctIdentifiers(uint256 i, uint256 j)
    hasDistinctIdentifiers(i, j)
{
    preserved updateWithdrawQueue(uint256[] indexes) with (env e) {
        requireInvariant distinctIdentifiers(indexes[i], indexes[j]);
    }
}

function isInWithdrawQueueIsEnabled(uint256 i) returns bool {
    if(i >= withdrawQueueLength()) return true;

    MetaMorphoHarness.Id id = withdrawQueue(i);
    bool enabled;
    _, enabled, _ = config(id);

    return enabled;
}

// Check that markets in the withdraw queue are enabled.
invariant inWithdrawQueueIsEnabled(uint256 i)
    isInWithdrawQueueIsEnabled(i)
filtered {
    f -> f.selector != sig:updateWithdrawQueue(uint256[]).selector
}

rule inWithdrawQueueIsEnabledPreservedUpdateWithdrawQueue(env e, uint256 i, uint256[] indexes) {
    uint256 j;
    require isInWithdrawQueueIsEnabled(indexes[i]);

    requireInvariant distinctIdentifiers(indexes[i], j);

    updateWithdrawQueue(e, indexes);

    MetaMorphoHarness.Id id = withdrawQueue(i);
    // Safe require because j is not otherwise constrained.
    // The ghost variable deletedAt is useful to make sure that markets are not permuted and deleted at the same time in updateWithdrawQueue.
    require j == deletedAt(id);

    assert isInWithdrawQueueIsEnabled(i);
}

function isWithdrawRankCorrect(MetaMorphoHarness.Id id) returns bool {
    uint256 rank = withdrawRank(id);

    if (rank == 0) return true;

    return withdrawQueue(assert_uint256(rank - 1)) == id;
}

// Checks that the withdraw rank of a market is given by the withdrawRank ghost variable.
invariant withdrawRankCorrect(MetaMorphoHarness.Id id)
    isWithdrawRankCorrect(id);

function isEnabledHasPositiveRank(MetaMorphoHarness.Id id) returns bool {
    bool enabled;
    _, enabled, _ = config(id);

    uint256 rank = withdrawRank(id);

    return enabled => rank > 0;
}

// Checks that enabled markets have a positive withdraw rank, according to the withdrawRank ghost variable.
invariant enabledHasPositiveRank(MetaMorphoHarness.Id id)
    isEnabledHasPositiveRank(id);

// Check that enabled markets are in the withdraw queue.
rule enabledIsInWithdrawQueue(MetaMorphoHarness.Id id) {
    bool enabled;
    _, enabled, _ = config(id);

    require enabled;

    requireInvariant enabledHasPositiveRank(id);
    requireInvariant withdrawRankCorrect(id);

    uint256 witness = assert_uint256(withdrawRank(id) - 1);
    assert withdrawQueue(witness) == id;
}
