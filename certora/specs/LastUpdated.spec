// SPDX-License-Identifier: GPL-2.0-or-later
import "Enabled.spec";

using MorphoHarness as Morpho;

methods {
    function Morpho.lastUpdate(MorphoHarness.Id) external returns(uint256) envfree;
    function Morpho.libId(MorphoHarness.MarketParams) external returns(MorphoHarness.Id) envfree;
}

// Check that any positive cap market must come from a market that has been created on Morpho Blue.
// The corresponding invariant cannot be verified because it requires to check properties on MetaMorpho and on Blue at the same time:
// - on MetaMorpho, that it holds when the cap is positive for the first time
// - on Blue, that a created market always has positive last update
function hasPositiveSupplyCapIsUpdated(MetaMorphoHarness.Id id) returns bool {
    uint192 supplyCap;
    supplyCap, _, _ = config(id);

    assert supplyCap > 0 => Morpho.lastUpdated(id) > 0;
}

// Check that any new market in the supply queue necessarily has a positive cap.
rule newSupplyQueueEnsuresPositiveCap(MetaMorphoHarness.Id[] newSupplyQueue) {
    uint256 i;

    setSupplyQueue(newSupplyQueue);

    require supplyQueue(i) == id;

    uint192 supplyCap;
    supplyCap, _, _ = config(id);
    assert supplyCap > 0;
}
