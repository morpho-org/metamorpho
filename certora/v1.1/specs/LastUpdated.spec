// SPDX-License-Identifier: GPL-2.0-or-later
import "ConsistentState.spec";

using MorphoHarness as Morpho;
using ERC20Helper as ERC20;

methods {
    function ERC20.balanceOf(address, address) external returns(uint256) envfree;
    function ERC20.totalSupply(address) external returns(uint256) envfree;
    function ERC20.safeTransferFrom(address, address, address, uint256) external envfree;

    function Morpho.lastUpdate(MorphoHarness.Id) external returns(uint256) envfree;
    function Morpho.virtualTotalSupplyAssets(MorphoHarness.Id) external returns(uint256) envfree;
    function Morpho.virtualTotalSupplyShares(MorphoHarness.Id) external returns(uint256) envfree;
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

// Check that any market with a positive cap is created on Morpho Blue.
// The corresponding invariant is difficult to verify because it requires to check properties on MetaMorpho and on Blue at the same time:
// - on MetaMorpho, that it holds when the cap is positive for the first time
// - on Blue, that a created market always has a positive last update
function hasPositiveSupplyCapIsUpdated(MetaMorphoHarness.Id id) returns bool {
    return config_(id).cap > 0 => Morpho.lastUpdate(id) > 0;
}

// Check that any new market in the supply queue necessarily has a positive cap.
rule newSupplyQueueEnsuresPositiveCap(env e, MetaMorphoHarness.Id[] newSupplyQueue) {
    uint256 i;

    setSupplyQueue(e, newSupplyQueue);

    MetaMorphoHarness.Id id = supplyQueue(i);

    assert config_(id).cap > 0;
}
