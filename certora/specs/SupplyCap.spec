// SPDX-License-Identifier: GPL-2.0-or-later

using MorphoHarness as Morpho;
using Util as Util;

methods {
    function MORPHO() external returns(address) envfree;
    function config_(MetaMorphoHarness.Id) external returns(MetaMorphoHarness.MarketConfig) envfree;

    function Morpho.accrueInterest(MetaMorphoHarness.MarketParams) external envfree;

    function Util.libId(MetaMorphoHarness.MarketParams) external returns(MetaMorphoHarness.Id) envfree;
    function Util.supplyAssets(address, MetaMorphoHarness.Id, address) external returns(uint256) envfree;
}

rule respectSupplyCap(method f, env e, calldataarg args)
{
    MetaMorphoHarness.MarketParams marketParams;
    MetaMorphoHarness.Id id = Util.libId(marketParams);

    address morpho = MORPHO();
    uint256 cap = config_(id).cap;

    Morpho.accrueInterest(marketParams);
    require Util.supplyAssets(morpho, id, currentContract) < cap;

    f(e, args);
    require assert_uint256(config_(id).cap) == cap;

    assert Util.supplyAssets(morpho, id, currentContract) < cap;
}
