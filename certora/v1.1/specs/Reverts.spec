// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

methods {
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
}

// Check all the revert conditions of the setCurator function.
rule setCuratorRevertCondition(env e, address newCurator) {
    address owner = owner();
    address oldCurator = curator();

    setCurator@withrevert(e, newCurator);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newCurator == oldCurator;
}

// Check all the revert conditions of the setIsAllocator function.
rule setIsAllocatorRevertCondition(env e, address newAllocator, bool newIsAllocator) {
    address owner = owner();
    bool wasAllocator = isAllocator(newAllocator);

    setIsAllocator@withrevert(e, newAllocator, newIsAllocator);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newIsAllocator == wasAllocator;
}

// Check all the revert conditions of the setSkimRecipient function.
rule setSkimRecipientRevertCondition(env e, address newSkimRecipient) {
    address owner = owner();
    address oldSkimRecipient = skimRecipient();

    setSkimRecipient@withrevert(e, newSkimRecipient);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newSkimRecipient == oldSkimRecipient;
}

// Check the input validation conditions under which the setFee function reverts.
// This function can also revert if interest accrual reverts.
rule setFeeInputValidation(env e, uint256 newFee) {
    address owner = owner();
    uint96 oldFee = fee();
    address feeRecipient = feeRecipient();

    setFee@withrevert(e, newFee);

    assert e.msg.value != 0 ||
           e.msg.sender != owner ||
           newFee == assert_uint256(oldFee) ||
           (newFee != 0 && feeRecipient == 0)
        => lastReverted;
}

// Check the input validation conditions under which the setFeeRecipient function reverts.
// This function can also revert if interest accrual reverts.
rule setFeeRecipientInputValidation(env e, address newFeeRecipient) {
    address owner = owner();
    uint96 fee = fee();
    address oldFeeRecipient = feeRecipient();

    setFeeRecipient@withrevert(e, newFeeRecipient);

    assert e.msg.value != 0 ||
           e.msg.sender != owner ||
           newFeeRecipient == oldFeeRecipient ||
           (fee != 0 && newFeeRecipient == 0)
        => lastReverted;
}

// Check all the revert conditions of the submitGuardian function.
rule submitGuardianRevertCondition(env e, address newGuardian) {
    address owner = owner();
    address oldGuardian = guardian();
    uint64 pendingGuardianValidAt = pendingGuardian_().validAt;

    requireInvariant timelockInRange();
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    submitGuardian@withrevert(e, newGuardian);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newGuardian == oldGuardian ||
        pendingGuardianValidAt != 0;
}

// Check all the revert conditions of the submitCap function.
rule submitCapRevertCondition(env e, MetaMorphoHarness.MarketParams marketParams, uint256 newSupplyCap) {
    MorphoHarness.Id id = Util.libId(marketParams);

    bool hasCuratorRole = hasCuratorRole(e.msg.sender);
    address asset = asset();
    uint256 lastUpdate = Morpho.lastUpdate(id);
    uint256 pendingCapValidAt = pendingCap_(id).validAt;
    MetaMorphoHarness.MarketConfig config = config_(id);

    requireInvariant timelockInRange();
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;
    requireInvariant supplyCapIsEnabled(id);

    submitCap@withrevert(e, marketParams, newSupplyCap);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasCuratorRole ||
        marketParams.loanToken != asset ||
        lastUpdate == 0 ||
        pendingCapValidAt != 0 ||
        config.removableAt != 0 ||
        newSupplyCap == assert_uint256(config.cap) ||
        newSupplyCap >= 2^184;
}

// Check all the revert conditions of the submitMarketRemoval function.
rule submitMarketRemovalRevertCondition(env e, MetaMorphoHarness.MarketParams marketParams) {
    MorphoHarness.Id id = Util.libId(marketParams);

    bool hasCuratorRole = hasCuratorRole(e.msg.sender);
    uint256 pendingCapValidAt = pendingCap_(id).validAt;
    MetaMorphoHarness.MarketConfig config = config_(id);

    requireInvariant timelockInRange();
    // Safe require as it corresponds to some time very far into the future.
    require e.block.timestamp < 2^63;

    submitMarketRemoval@withrevert(e, marketParams);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasCuratorRole ||
        pendingCapValidAt != 0 ||
        config.cap != 0 ||
        !config.enabled ||
        config.removableAt != 0;
}

// Check the input validation conditions under which the setSupplyQueue function reverts.
// There are no other condition under which this function reverts, but it cannot be expressed easily because of the encoding of the universal quantifier chosen.
rule setSupplyQueueInputValidation(env e, MorphoHarness.Id[] newSupplyQueue) {
    bool hasAllocatorRole = hasAllocatorRole(e.msg.sender);
    uint256 maxQueueLength = maxQueueLength();
    uint256 i;
    require i < newSupplyQueue.length;
    uint184 anyCap = config_(newSupplyQueue[i]).cap;

    setSupplyQueue@withrevert(e, newSupplyQueue);

    assert e.msg.value != 0 ||
           !hasAllocatorRole ||
           newSupplyQueue.length > maxQueueLength ||
           anyCap == 0
        => lastReverted;
}

// Check the input validation conditions under which the updateWithdrawQueue function reverts.
// This function can also revert if a market is removed when it shouldn't:
//   - a removed market should have 0 supply cap
//   - a removed market should not have a pending cap
//   - a removed market should either have no supply or (be marked for forced removal and that timestamp has elapsed)
rule updateWithdrawQueueInputValidation(env e, uint256[] indexes) {
    bool hasAllocatorRole = hasAllocatorRole(e.msg.sender);
    uint256 i;
    require i < indexes.length;
    uint256 j;
    require j < indexes.length;
    uint256 anyIndex = indexes[i];
    uint256 oldLength = withdrawQueueLength();
    uint256 anyOtherIndex = indexes[j];

    updateWithdrawQueue@withrevert(e, indexes);

    assert e.msg.value != 0 ||
           !hasAllocatorRole ||
           anyIndex > oldLength ||
           (i != j && anyOtherIndex == anyIndex)
        => lastReverted;
}

// Check the input validation conditions under which the reallocate function reverts.
// This function can also revert for non enabled markets and if the total withdrawn differs from the total supplied.
rule reallocateInputValidation(env e, MetaMorphoHarness.MarketAllocation[] allocations) {
    bool hasAllocatorRole = hasAllocatorRole(e.msg.sender);

    reallocate@withrevert(e, allocations);

    assert e.msg.value != 0 ||
           !hasAllocatorRole
        => lastReverted;
}

// Check all the revert conditions of the revokePendingTimelock function.
rule revokePendingTimelockRevertCondition(env e) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);

    revokePendingTimelock@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasGuardianRole;
}

// Check all the revert conditions of the revokePendingGuardian function.
rule revokePendingGuardianRevertCondition(env e) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);

    revokePendingGuardian@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasGuardianRole;
}

// Check all the revert conditions of the revokePendingCap function.
rule revokePendingCapRevertCondition(env e, MorphoHarness.Id id) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);
    bool hasCuratorRole = hasCuratorRole(e.msg.sender);

    revokePendingCap@withrevert(e, id);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !(hasGuardianRole || hasCuratorRole);
}

// Check all the revert conditions of the revokePendingMarketRemoval function.
rule revokePendingMarketRemovalRevertCondition(env e, MorphoHarness.Id id) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);
    bool hasCuratorRole = hasCuratorRole(e.msg.sender);

    revokePendingMarketRemoval@withrevert(e, id);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !(hasGuardianRole || hasCuratorRole);
}

// Check all the revert conditions of the acceptTimelock function.
rule acceptTimelockRevertCondition(env e) {
    uint256 pendingTimelockValidAt = pendingTimelock_().validAt;

    acceptTimelock@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        pendingTimelockValidAt == 0 ||
        pendingTimelockValidAt > e.block.timestamp;
}

// Check all the revert conditions of the acceptGuardian function.
rule acceptGuardianRevertCondition(env e) {
    uint256 pendingGuardianValidAt = pendingGuardian_().validAt;

    acceptGuardian@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        pendingGuardianValidAt == 0 ||
        pendingGuardianValidAt > e.block.timestamp;
}

// Check the input validation conditions under which the acceptCap function reverts.
// This function can also revert if interest accrual reverts or if it would lead to growing the withdraw queue past the max length.
rule acceptCapInputValidation(env e, MetaMorphoHarness.MarketParams marketParams) {
    MetaMorphoHarness.Id id = Util.libId(marketParams);

    uint256 pendingCapValidAt = pendingCap_(id).validAt;

    acceptCap@withrevert(e, marketParams);

    assert e.msg.value != 0 ||
           pendingCapValidAt == 0 ||
           pendingCapValidAt > e.block.timestamp
        => lastReverted;
}

// Check all the revert conditions of the skim function.
rule skimRevertCondition(env e, address token) {
    address skimRecipient = skimRecipient();

    require skimRecipient != currentContract => ERC20.balanceOf(token, skimRecipient) + ERC20.balanceOf(token, currentContract) <= to_mathint(ERC20.totalSupply(token));

    skim@withrevert(e, token);

    assert lastReverted <=>
        e.msg.value != 0 ||
        skimRecipient == 0;
}

// The mint, deposit, withdraw and redeem functions do not require to validate their input.
