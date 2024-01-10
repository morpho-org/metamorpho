// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function owner() external returns(address) envfree;
    function curator() external returns(address) envfree;
}

rule setCuratorRevertCondition(env e, address newCurator) {
    address oldCurator = curator();
    address owner = owner();

    setCurator@withrevert(e, newCurator);

    assert lastReverted <=> oldCurator == newCurator || e.msg.sender != owner;
}
