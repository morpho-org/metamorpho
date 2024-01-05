// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function owner() external returns address envfree;
    function curator() external returns address envfree;
    function isAllocator(address target) external returns bool envfree;
}

rule curatorIsAllocator(method f, calldataarg args) {
    storage initial = lastStorage;

    env e1; env e2;
    require e1.block.timestamp == e2.block.timestamp;
    require e1.msg.value == e2.msg.value;

    require isAllocator(e1.msg.sender) && e1.msg.sender != owner();
    f@withrevert(e1, args) at initial;
    bool revertedAllocator = lastReverted;

    require e2.msg.sender == curator();
    f@withrevert(e2, args) at initial;
    bool revertedCurator = lastReverted;

    assert revertedCurator => revertedAllocator;
}
