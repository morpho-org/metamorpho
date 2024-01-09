// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function owner() external returns(address) envfree;
    function curator() external returns(address) envfree;
    function guardian() external returns(address) envfree;
    function isAllocator(address target) external returns(bool) envfree;

    function _.idToMarketParams(MetaMorphoHarness.Id) external => AUTO;
    function _.supplyShares(MetaMorphoHarness.Id, address) external => AUTO;
    function _.accrueInterest(MetaMorphoHarness.MarketParams) external => AUTO;

    function _.balanceOf(address) external => AUTO;

    function SafeERC20.safeTransfer(address, address, uint256) internal => CONSTANT;
    function SafeERC20.safeTransferFrom(address, address, address, uint256) internal => CONSTANT;
}

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
    f@withrevert(e1, args) at initial;
    bool revertedAllocator = lastReverted;

    require e2.msg.sender == curator();
    f@withrevert(e2, args) at initial;
    bool revertedCurator = lastReverted;

    assert revertedCurator => revertedAllocator;
}
