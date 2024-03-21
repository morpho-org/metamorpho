// SPDX-License-Identifier: GPL-2.0-or-later
import "Enabled.spec";

using MorphoHarness as Morpho;

methods {
    function Morpho.supply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) external returns (uint256, uint256) with (env e) => summarySupply(e, marketParams, assets, shares, onBehalf, data);
    function Morpho.withdraw(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256) with (env e) => summaryWithdraw(e, marketParams, assets, shares, onBehalf, receiver);
    function Morpho.libId(MorphoHarness.MarketParams) external returns(MorphoHarness.Id) envfree;
    function Morpho.idToMarketParams(MetaMorphoHarness.Id id) external => summaryIdToMarketParams(id) expect MetaMorphoHarness.MarketParams ALL;
}

function summaryIdToMarketParams(MetaMorphoHarness.Id id) returns MetaMorphoHarness.MarketParams {
    MetaMorphoHarness.MarketParams marketParams;
    uint256 lastUpdated = Morpho.lastUpdate(id);

    // Safe require because markets in the supply/withdraw queue have positive last update (see LastUpdated.spec).
    require lastUpdated > 0;
    // Safe require because it is a verified invariant in Morpho Blue.
    require lastUpdated > 0 => Morpho.libId(marketParams) == id;

    return marketParams;
}

function summarySupply(env e, MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) returns(uint256, uint256) {
    assert shares == 0;
    assert onBehalf == currentContract;
    assert data.length == 0;

    MetaMorphoHarness.Id id = Morpho.libId(marketParams);
    // Safe require because it is a verified invariant
    require hasSupplyCapIsEnabled(id);

    // Check that all markets on which MetaMorpho supplies are enabled markets.
    assert config_(id).enabled;

    uint256 retAssets; uint256 retShares;
    retAssets, retShares = Morpho.supply(e, marketParams, assets, shares, onBehalf, data);
    return (retAssets, retShares);
}

function summaryWithdraw(env e, MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) returns (uint256, uint256) {
    assert onBehalf == currentContract;
    assert receiver == currentContract;

    MetaMorphoHarness.Id id = Morpho.libId(marketParams);
    uint256 rank = withdrawRank(id);
    // Safe require because it is a verified invariant.
    require isInWithdrawQueueIsEnabled(assert_uint256(rank - 1));

    // Check that all markets from which MetaMorpho withdraws are enabled markets.
    assert config_(id).enabled;

    uint256 retAssets; uint256 retShares;
    retAssets, retShares = Morpho.withdraw(e, marketParams, assets, shares, onBehalf, receiver);
    return (retAssets, retShares);
}

invariant checkSummaries()
    true;
