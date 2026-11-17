// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    // Only verify the admin functions, not the main entrypoints.
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;
    function deposit(uint256, address) external returns(uint256) => NONDET DELETE;
    function mint(uint256, address) external returns(uint256) => NONDET DELETE;
    function withdraw(uint256, address, address) external returns(uint256) => NONDET DELETE;
    function redeem(uint256, address, address) external returns(uint256) => NONDET DELETE;

    function owner() external returns(address) envfree;
    function pendingOwner() external returns(address) envfree;
    function curator() external returns(address) envfree;
    function guardian() external returns(address) envfree;
    function isAllocator(address target) external returns(bool) envfree;

    // Summarize Morpho external calls, as they don't depend on the authorization system of MetaMorpho.
    function _.idToMarketParams(MetaMorphoHarness.Id) external => CONSTANT;
    function _.supplyShares(MetaMorphoHarness.Id, address) external => CONSTANT;
    function _.accrueInterest(MetaMorphoHarness.MarketParams) external => CONSTANT;
    function _.expectedSupplyAssets(MetaMorphoHarness.MarketParams, address) external => CONSTANT;
    function _.lastUpdate(MetaMorphoHarness.Id) external => CONSTANT;
    function _.market(MetaMorphoHarness.Id) external => CONSTANT;
    function _.supply(MetaMorphoHarness.MarketParams, uint256, uint256, address, bytes) external => CONSTANT;
    function _.withdraw(MetaMorphoHarness.MarketParams, uint256, uint256, address, address) external => CONSTANT;

    // Summarize MetaMorpho seen as a token, useful for `transferFrom`.
    function allowance(address, address) internal returns(uint256) => CONSTANT;
    function ERC20._transfer(address, address, uint256) internal => CONSTANT;

    // Summarize other tokens, useful for `skim`.
    function _.balanceOf(address) external => CONSTANT;
    function SafeERC20.safeTransfer(address, address, uint256) internal => CONSTANT;
}

// Check that the owner has more power than the guardian.
rule ownerIsGuardian(method f, calldataarg args)
filtered {
    f -> !f.isView
}
{
    storage initial = lastStorage;

    env e1; env e2;
    require e1.block.timestamp == e2.block.timestamp;
    require e1.msg.value == e2.msg.value;

    require e1.msg.sender != 0;
    require e2.msg.sender != 0;

    require e1.msg.sender == guardian();
    require e1.msg.sender != owner();
    require e1.msg.sender != pendingOwner();
    f@withrevert(e1, args) at initial;
    bool revertedGuardian = lastReverted;

    require e2.msg.sender == owner();
    f@withrevert(e2, args) at initial;
    bool revertedOwner = lastReverted;

    assert revertedOwner => revertedGuardian;
}

// Check that the owner has more power than the curator.
rule ownerIsCurator(method f, calldataarg args)
filtered {
    f -> !f.isView
}
{
    storage initial = lastStorage;

    env e1; env e2;
    require e1.block.timestamp == e2.block.timestamp;
    require e1.msg.value == e2.msg.value;

    require e1.msg.sender != 0;
    require e2.msg.sender != 0;

    require e1.msg.sender == curator();
    require e1.msg.sender != owner();
    require e1.msg.sender != pendingOwner();
    f@withrevert(e1, args) at initial;
    bool revertedCurator = lastReverted;

    require e2.msg.sender == owner();
    f@withrevert(e2, args) at initial;
    bool revertedOwner = lastReverted;

    assert revertedOwner => revertedCurator;
}

// Check that the curator has more power than allocators.
rule curatorIsAllocator(method f, calldataarg args)
filtered {
    f -> !f.isView
}
{
    storage initial = lastStorage;

    env e1; env e2;
    require e1.block.timestamp == e2.block.timestamp;
    require e1.msg.value == e2.msg.value;

    require e1.msg.sender != 0;
    require e2.msg.sender != 0;

    require isAllocator(e1.msg.sender);
    require e1.msg.sender != owner();
    require e1.msg.sender != guardian();
    require e1.msg.sender != pendingOwner();
    f@withrevert(e1, args) at initial;
    bool revertedAllocator = lastReverted;

    require e2.msg.sender == curator();
    f@withrevert(e2, args) at initial;
    bool revertedCurator = lastReverted;

    assert revertedCurator => revertedAllocator;
}
