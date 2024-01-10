// SPDX-License-Identifier: GPL-2.0-or-later
import "ConsistentState.spec";

using MorphoHarness as Morpho;

methods {
    function asset() external returns(address) envfree;
    function owner() external returns(address) envfree;
    function curator() external returns(address) envfree;
    function isAllocator(address) external returns(bool) envfree;
    function skimRecipient() external returns(address) envfree;

    function Morpho.libId(MorphoHarness.MarketParams) external returns(MorphoHarness.Id) envfree;
    function Morpho.lastUpdate(MorphoHarness.Id) external returns(uint256) envfree;
}

use invariant timelockInRange;

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

    requireInvariant timelockInRange();
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

    address asset = asset();
    uint256 lastUpdate = Morpho.lastUpdate(id);
    uint256 pendingCapValidAt;
    _, pendingCapValidAt = pendingCap(id);
    uint256 supplyCap;
    uint256 removableAt;
    supplyCap, _, removableAt = config(id);

    submitCap@withrevert(e, marketParams, newSupplyCap);

    assert marketParams.loanToken != asset ||
           lastUpdate == 0 ||
           pendingCapValidAt != 0 ||
           removableAt != 0 ||
           newSupplyCap == supplyCap
        => lastReverted;
}
