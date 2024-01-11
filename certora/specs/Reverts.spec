// SPDX-License-Identifier: GPL-2.0-or-later
import "ConsistentState.spec";

using MorphoHarness as Morpho;

methods {
    function asset() external returns(address) envfree;
    function owner() external returns(address) envfree;
    function curator() external returns(address) envfree;
    function isAllocator(address) external returns(bool) envfree;
    function skimRecipient() external returns(address) envfree;
    function fee() external returns(uint96) envfree;
    function feeRecipient() external returns(address) envfree;
    function guardian() external returns(address) envfree;
    function pendingGuardian() external returns(address, uint64) envfree;
    function config(MorphoHarness.Id) external returns(uint184, bool, uint64) envfree;
    function pendingCap(MorphoHarness.Id) external returns(uint192, uint64) envfree;

    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
    function totalSupply(address) external returns(uint256) envfree;
    function balanceOf(address, address) external returns(uint256) envfree;

    function Morpho.libId(MorphoHarness.MarketParams) external returns(MorphoHarness.Id) envfree;
    function Morpho.lastUpdate(MorphoHarness.Id) external returns(uint256) envfree;
}

function hasCuratorRole(address user) returns bool {
    return user == owner() || user == curator();
}

function hasAllocatorRole(address user) returns bool {
    return user == owner() || user == curator() || isAllocator(user);
}

function hasGuardianRole(address user) returns bool {
    return user == owner() || user == guardian();
}

rule setCuratorRevertCondition(env e, address newCurator) {
    address owner = owner();
    address oldCurator = curator();

    setCurator@withrevert(e, newCurator);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newCurator == oldCurator;
}

rule setIsAllocatorRevertCondition(env e, address newAllocator, bool newIsAllocator) {
    address owner = owner();
    bool wasAllocator = isAllocator(newAllocator);

    setIsAllocator@withrevert(e, newAllocator, newIsAllocator);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newIsAllocator == wasAllocator;
}

rule setSkimRecipientRevertCondition(env e, address newSkimRecipient) {
    address owner = owner();
    address oldSkimRecipient = skimRecipient();

    setSkimRecipient@withrevert(e, newSkimRecipient);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newSkimRecipient == oldSkimRecipient;
}

rule setFeeRevertInputValidation(env e, uint256 newFee) {
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

rule submitGuardianRevertCondition(env e, address newGuardian) {
    address owner = owner();
    address oldGuardian = guardian();
    uint64 pendingGuardianValidAt;
    _, pendingGuardianValidAt = pendingGuardian();

    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require as it corresponds to year 2262.
    require e.block.timestamp < 2^63;

    submitGuardian@withrevert(e, newGuardian);

    assert lastReverted <=>
        e.msg.value != 0 ||
        e.msg.sender != owner ||
        newGuardian == oldGuardian ||
        pendingGuardianValidAt != 0;
}

rule submitCapInputValidation(env e, MetaMorphoHarness.MarketParams marketParams, uint256 newSupplyCap) {
    MorphoHarness.Id id = Morpho.libId(marketParams);

    bool hasCuratorRole = hasCuratorRole(e.msg.sender);
    address asset = asset();
    uint256 lastUpdate = Morpho.lastUpdate(id);
    uint256 pendingCapValidAt;
    _, pendingCapValidAt = pendingCap(id);
    uint184 supplyCap;
    uint64 removableAt;
    supplyCap, _, removableAt = config(id);

    submitCap@withrevert(e, marketParams, newSupplyCap);

    assert e.msg.value != 0 ||
           !hasCuratorRole ||
           marketParams.loanToken != asset ||
           lastUpdate == 0 ||
           pendingCapValidAt != 0 ||
           removableAt != 0 ||
           newSupplyCap == assert_uint256(supplyCap)
        => lastReverted;
}

rule submitMarketRemovalRevertCondition(env e, MetaMorphoHarness.MarketParams marketParams) {
    MorphoHarness.Id id = Morpho.libId(marketParams);

    bool hasCuratorRole = hasCuratorRole(e.msg.sender);
    uint256 pendingCapValidAt;
    _, pendingCapValidAt = pendingCap(id);
    uint184 supplyCap;
    bool enabled;
    uint64 oldRemovableAt;
    supplyCap, enabled, oldRemovableAt = config(id);

    // Safe require because it is a verified invariant.
    require isTimelockInRange();
    // Safe require as it corresponds to year 2262.
    require e.block.timestamp < 2^63;

    submitMarketRemoval@withrevert(e, marketParams);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasCuratorRole ||
        pendingCapValidAt != 0 ||
        supplyCap != 0 ||
        !enabled ||
        oldRemovableAt != 0;
}

rule setSupplyQueueInputValidation(env e, MorphoHarness.Id[] newSupplyQueue) {
    bool hasAllocatorRole = hasAllocatorRole(e.msg.sender);
    uint256 maxQueueLength = maxQueueLength();
    uint256 i;
    require i < newSupplyQueue.length;
    uint184 anyCap;
    anyCap, _, _ = config(newSupplyQueue[i]);

    setSupplyQueue@withrevert(e, newSupplyQueue);

    assert e.msg.value != 0 ||
           !hasAllocatorRole ||
           newSupplyQueue.length > maxQueueLength ||
           anyCap == 0
        => lastReverted;
}

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

rule reallocateInputValidation(env e, MetaMorphoHarness.MarketAllocation[] allocations) {
    bool hasAllocatorRole = hasAllocatorRole(e.msg.sender);

    reallocate@withrevert(e, allocations);

    assert e.msg.value != 0 ||
           !hasAllocatorRole
        => lastReverted;
}

rule revokePendingTimelockRevertCondition(env e) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);

    revokePendingTimelock@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasGuardianRole;
}

rule revokePendingGuardianRevertCondition(env e) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);

    revokePendingGuardian@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasGuardianRole;
}

rule revokePendingCapRevertCondition(env e, MorphoHarness.Id id) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);
    bool hasCuratorRole = hasCuratorRole(e.msg.sender);

    revokePendingCap@withrevert(e, id);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !(hasGuardianRole || hasCuratorRole);
}

rule revokePendingMarketRemovalRevertCondition(env e, MorphoHarness.Id id) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);
    bool hasCuratorRole = hasCuratorRole(e.msg.sender);

    revokePendingMarketRemoval@withrevert(e, id);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !(hasGuardianRole || hasCuratorRole);
}

rule acceptTimelockRevertCondition(env e) {
    uint256 pendingTimelockValidAt;
    _, pendingTimelockValidAt = pendingTimelock();

    acceptTimelock@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        pendingTimelockValidAt == 0 ||
        pendingTimelockValidAt > e.block.timestamp;
}

rule acceptGuardianRevertCondition(env e) {
    uint256 pendingGuardianValidAt;
    _, pendingGuardianValidAt = pendingGuardian();

    acceptGuardian@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        pendingGuardianValidAt == 0 ||
        pendingGuardianValidAt > e.block.timestamp;
}

rule acceptCapInputValidation(env e, MetaMorphoHarness.MarketParams marketParams) {
    MetaMorphoHarness.Id id = Morpho.libId(marketParams);

    uint256 pendingCapValidAt;
    _, pendingCapValidAt = pendingCap(id);

    acceptCap@withrevert(e, marketParams);

    assert e.msg.value != 0 ||
           pendingCapValidAt == 0 ||
           pendingCapValidAt > e.block.timestamp
        => lastReverted;
}

rule skimRevertCondition(env e, address token) {
    address skimRecipient = skimRecipient();

    require skimRecipient != currentContract => balanceOf(token, skimRecipient) + balanceOf(token, currentContract) <= to_mathint(totalSupply(token));

    skim@withrevert(e, token);

    assert lastReverted <=>
        e.msg.value != 0 ||
        skimRecipient == 0;
}

// The mint, deposit, withdraw and redeem functions do not require to validate their input.
