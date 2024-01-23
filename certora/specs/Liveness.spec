// SPDX-License-Identifier: GPL-2.0-or-later
import "Reverts.spec";

methods {
    function supplyQueue(uint256) external returns(MetaMorphoHarness.Id) envfree;
}

// Check that having the allocator role allows to pause supply on the vault.
rule canPauseSupply() {
    env e1; MetaMorphoHarness.Id[] newSupplyQueue;
    require newSupplyQueue.length == 0;
    require e1.msg.value == 0;
    require hasAllocatorRole(e1.msg.sender);

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

rule canForceRemoveMarket(MetaMorphoHarness.MarketParams marketParams) {
    MetaMorphoHarness.Id id = Morpho.libId(marketParams);

    uint184 supplyCap; uint64 removableAt;
    supplyCap, _, removableAt = config(id);
    require supplyCap > 0;
    require removableAt == 0;
    require supplyQueue(1) == id;

    env e1; env e2; env e3;
    require hasCuratorRole(e1.msg.sender);
    require e2.msg.sender == e1.msg.sender;
    require e3.msg.sender == e1.msg.sender;

    require e1.msg.value == 0;
    revokePendingCap@withrevert(e1, id);
    assert !lastReverted;

    require e2.msg.value == 0;
    submitCap@withrevert(e2, marketParams, 0);
    assert !lastReverted;

    require e3.msg.value == 0;
    submitMarketRemoval@withrevert(e3, marketParams);
    assert !lastReverted;
}
