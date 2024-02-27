// SPDX-License-Identifier: GPL-2.0-or-later
import "Enabled.spec";

using MorphoHarness as Morpho;

methods {
    function Morpho.lastUpdate(MorphoHarness.Id) external returns(uint256) envfree;
    function Morpho.libId(MorphoHarness.MarketParams) external returns(MorphoHarness.Id) envfree;
}

rule newPositiveCapEnsuresUpdated(env e, method f, calldataarg args) {
    MetaMorphoHarness.Id id;

    uint192 supplyCapBefore;
    supplyCapBefore, _, _ = config(id);
    require supplyCapBefore == 0;

    f(e, args);

    uint192 supplyCapAfter;
    supplyCapAfter, _, _ = config(id);
    require supplyCapAfter > 0;

    assert Morpho.lastUpdate(id) > 0;
}

rule newSupplyQueueEnsuresPositiveCap(env e, method f, calldataarg args) {
    MetaMorphoHarness.Id id;
    uint256 i;

    f(e, args);

    require supplyQueue(i) == id;

    uint192 supplyCap;
    supplyCap, _, _ = config(id);
    assert supplyCap == 0;
}
