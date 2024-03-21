// SPDX-License-Identifier: GPL-2.0-or-later
import "ConsistentState.spec";

using MorphoHarness as M;

methods {
    function M.supply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) external returns (uint256, uint256) with (env e) => summarySupply(e, marketParams, assets, shares, onBehalf, data);
    function M.withdraw(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256) with (env e) => summaryWithdraw(e, marketParams, assets, shares, onBehalf, receiver);
    function M.libId(MetaMorphoHarness.MarketParams) external returns(MetaMorphoHarness.Id) envfree;
    function M.lastUpdate(MetaMorphoHarness.Id) external returns(uint256) envfree;
    function _.idToMarketParams(MetaMorphoHarness.Id id) external => summaryIdToMarketParams(id) expect MetaMorphoHarness.MarketParams ALL;
}

function summaryIdToMarketParams(MetaMorphoHarness.Id id) returns MetaMorphoHarness.MarketParams {
    MetaMorphoHarness.MarketParams marketParams;
    uint256 lastUpdated = M.lastUpdate(id);

    // Safe require because markets in the supply/withdraw queue have positive last update (see LastUpdated.spec).
    require lastUpdated > 0;
    // Safe require because it is a verified invariant in M Blue.
    require lastUpdated > 0 => M.libId(marketParams) == id;

    return marketParams;
}

function summarySupply(env e, MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) returns(uint256, uint256) {
    assert shares == 0;
    assert onBehalf == currentContract;
    assert data.length == 0;

    MetaMorphoHarness.Id id = M.libId(marketParams);
    // Safe require because it is a verified invariant
    require hasSupplyCapIsEnabled(id);

    // Check that all markets on which MetaMorpho supplies are enabled markets.
    assert config_(id).enabled;

    uint256 retAssets; uint256 retShares;
    retAssets, retShares = M.supply(e, marketParams, assets, shares, onBehalf, data);
    return (retAssets, retShares);
}

function summaryWithdraw(env e, MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) returns (uint256, uint256) {
    assert onBehalf == currentContract;
    assert receiver == currentContract;

    MetaMorphoHarness.Id id = M.libId(marketParams);
    uint256 rank = withdrawRank(id);
    // Safe require because it is a verified invariant.
    require isInWithdrawQueueIsEnabled(assert_uint256(rank - 1));
    // Safe require because it is a verified invariant
    require isWithdrawRankCorrect(id);

    // Check that all markets from which MetaMorpho withdraws are enabled markets.
    assert config_(id).enabled;

    uint256 retAssets; uint256 retShares;
    retAssets, retShares = M.withdraw(e, marketParams, assets, shares, onBehalf, receiver);
    return (retAssets, retShares);
}

invariant checkSummaries()
    true;
