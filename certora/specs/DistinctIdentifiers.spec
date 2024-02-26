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
