// SPDX-License-Identifier: GPL-2.0-or-later

using MorphoHarness as Morpho;

methods {
    function Morpho.supplyShares(MorphoHarness.Id, address) external returns(uint256) envfree;
    function Morpho.totalSupplyAssets(MorphoHarness.Id) external returns(uint256) envfree;
    function Morpho.totalSupplyShares(MorphoHarness.Id) external returns(uint256) envfree;

    function Util.accrueInterest(address, MorphoHarness.Id) external returns(uint256) envfree;
    function Util.supplyAssets(address, MorphoHarness.Id, address) external envfree;

    function MORPHO() external returns(address) envfree;
}

methods {
    function config_(MetaMorphoHarness.Id) external returns(MetaMorphoHarness.MarketConfig) envfree;
}

rule respectSupplyCap(method f, env e, calldataarg args)
{
    MetaMorphoHarness.Id id;
    address morpho = MORPHO();
    uint256 cap = config_(id).cap;

    Util.accrueInterest(morpho, id);
    require Util.supplyAssets(morpho, id, currentContract) < cap;

    f(e, args);
    require config_(id).cap == cap;

    assert Util.supplyAssets(morpho, id, currentContract) < cap;
}
