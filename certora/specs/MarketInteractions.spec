// SPDX-License-Identifier: GPL-2.0-or-later
import "Enabled.spec";

using MorphoHarness as Morpho;

methods {
    function Morpho.supply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) external returns (uint256, uint256) with (env e) => summarySupply(e, marketParams, assets, shares, onBehalf, data);
    function Morpho.withdraw(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256) with (env e) => summaryWithdraw(e, marketParams, assets, shares, onBehalf, receiver);
    function Morpho.libId(MorphoHarness.MarketParams) external returns(MorphoHarness.Id) envfree;
}

function summarySupply(env e, MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) returns(uint256, uint256) {
    assert shares == 0;
    assert onBehalf == currentContract;
    assert data.length == 0;

    uint256 retAssets; uint256 retShares;
    retAssets, retShares = Morpho.supply(e, marketParams, assets, shares, onBehalf, data);
    return (retAssets, retShares);
}

function summaryWithdraw(env e, MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) returns (uint256, uint256) {
    assert onBehalf == currentContract;
    assert receiver == currentContract;

    uint256 retAssets; uint256 retShares;
    retAssets, retShares = Morpho.withdraw(e, marketParams, assets, shares, onBehalf, receiver);
    return (retAssets, retShares);
}

invariant checkSummaries()
    true;
