// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function owner() external returns(address) envfree;
    function isAllocator(address) external returns(bool) envfree;
}

// Check that having the allocator role allows to pause supply on the vault.
rule canPauseSupply(env e1, MetaMorphoHarness.Id[] newSupplyQueue) {
    require newSupplyQueue.length == 0;
    require e1.msg.value == 0;
    require e1.msg.sender == owner() || isAllocator(e1.msg.sender);

    setSupplyQueue@withrevert(e1, newSupplyQueue);
    assert !lastReverted;

    storage pausedSupply = lastStorage;

    env e2; uint256 assets2; address receiver2;
    require assets2 != 0;
    deposit@withrevert(e2, assets2, receiver2) at pausedSupply;
    assert lastReverted;

    env e3; uint256 shares3; address receiver3;
    uint256 assets3 = mint@withrevert(e3, shares3, receiver3) at pausedSupply;
    require assets3 != 0;
    assert lastReverted;
}
