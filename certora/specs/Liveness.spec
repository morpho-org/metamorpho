// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;
}

rule canPauseSupply(env e1, MetaMorphoHarness.Id[] newSupplyQueue) {
    require newSupplyQueue.length == 0;

    setSupplyQueue(e1, newSupplyQueue);

    storage pausedSupply = lastStorage;

    env e2; uint256 assets2; address receiver2;
    deposit@withrevert(e2, assets2, receiver2) at pausedSupply;
    assert lastReverted;

    env e3; uint256 shares3; address receiver3;
    mint@withrevert(e3, shares3, receiver3) at pausedSupply;
    assert lastReverted;
}
