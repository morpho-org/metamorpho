// SPDX-License-Identifier: GPL-2.0-or-later

// Persistent because their consumers do not observe queue ghosts after reverted calls.
persistent ghost mapping(MetaMorphoHarness.Id => uint256) withdrawRank {
    init_state axiom forall MetaMorphoHarness.Id id. withdrawRank[id] == 0;
}

persistent ghost mapping(MetaMorphoHarness.Id => uint256) deletedAt {
    init_state axiom forall MetaMorphoHarness.Id id. deletedAt[id] == 0;
}

persistent ghost uint256 lastIndexWithdraw {
    init_state axiom lastIndexWithdraw == 0;
}

persistent ghost uint256 withdrawQueueLengthGhost {
    init_state axiom withdrawQueueLengthGhost == 0;
}

hook Sload uint256 length currentContract.withdrawQueue.length {
    withdrawQueueLengthGhost = length;
}

hook Sstore currentContract.withdrawQueue.length uint256 length {
    if (length < withdrawQueueLengthGhost) {
        havoc withdrawRank assuming forall MetaMorphoHarness.Id id. withdrawRank@new[id] == (withdrawRank@old[id] > length ? 0 : withdrawRank@old[id]);
    }
    withdrawQueueLengthGhost = length;
}

hook Sload MetaMorphoHarness.Id id withdrawQueue[INDEX uint256 i] {
    lastIndexWithdraw = i;
}

hook Sstore withdrawQueue[INDEX uint256 i] MetaMorphoHarness.Id newId (MetaMorphoHarness.Id oldId) {
    if (withdrawRank[oldId] == i + 1) {
        withdrawRank[oldId] = 0;
    }
    if (i < withdrawQueueLengthGhost) {
        withdrawRank[newId] = assert_uint256(i + 1);
    }
}

hook Sstore config[KEY MetaMorphoHarness.Id id].enabled bool enabled {
    if (!enabled) {
        deletedAt[id] = lastIndexWithdraw;
    }
}
