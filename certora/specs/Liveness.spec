// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

// Check that having the allocator role allows to pause supply on the vault.
rule canPauseSupply() {
    env e1; MetaMorphoHarness.Id[] newSupplyQueue;
    require e1.msg.value == 0;
    require hasAllocatorRole(e1.msg.sender);
    require newSupplyQueue.length == 0;

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
    MetaMorphoHarness.Id id = Util.libId(marketParams);

    requireInvariant supplyCapIsEnabled(id);
    requireInvariant enabledHasConsistentAsset(marketParams);
    // Safe require because this holds as an invariant.
    require hasPositiveSupplyCapIsUpdated(id);

    MetaMorphoHarness.MarketConfig config = config_(id);
    require config.cap > 0;
    require config.removableAt == 0;
    // Assume that the withdraw queue is [X, id];
    require withdrawQueue(1) == id;
    require withdrawQueueLength() == 2;

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
    requireInvariant timelockInRange();
    // Safe require as it corresponds to some time very far into the future.
    require e3.block.timestamp < 2^63;
    submitMarketRemoval@withrevert(e3, marketParams);
    assert !lastReverted;

    env e4; uint256[] newWithdrawQueue;
    require newWithdrawQueue.length == 1;
    require newWithdrawQueue[0] == 0;
    require e4.msg.value == 0;
    require hasAllocatorRole(e4.msg.sender);
    require to_mathint(e4.block.timestamp) >= e3.block.timestamp + timelock();
    updateWithdrawQueue@withrevert(e4, newWithdrawQueue);
    assert !lastReverted;

    assert !config_(id).enabled;
}
