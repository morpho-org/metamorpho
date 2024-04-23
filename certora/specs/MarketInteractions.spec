// SPDX-License-Identifier: GPL-2.0-or-later
import "ConsistentState.spec";

methods {
    function _.supply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) external => summarySupply(marketParams, assets, shares, onBehalf, data) expect (uint256, uint256) ALL;
    function _.withdraw(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external => summaryWithdraw(marketParams, assets, shares, onBehalf, receiver) expect (uint256, uint256) ALL;
    function _.idToMarketParams(MetaMorphoHarness.Id id) external => summaryIdToMarketParams(id) expect MetaMorphoHarness.MarketParams ALL;

    function lastIndexWithdraw() external returns(uint256) envfree;
}

function summaryIdToMarketParams(MetaMorphoHarness.Id id) returns MetaMorphoHarness.MarketParams {
    MetaMorphoHarness.MarketParams marketParams;

    // Safe require because:
    // - markets in the supply/withdraw queue have positive lastUpdate (see LastUpdated.spec)
    // - lastUpdate(id) > 0 => marketParams.id() == id is a verified invariant in Morpho Blue.
    require Util.libId(marketParams) == id;

    return marketParams;
}

function summarySupply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) returns(uint256, uint256) {
    assert shares == 0;
    assert assets != 0;
    assert onBehalf == currentContract;
    assert data.length == 0;

    MetaMorphoHarness.Id id = Util.libId(marketParams);
    requireInvariant supplyCapIsEnabled(id);

    // Check that all markets on which MetaMorpho supplies are enabled markets.
    assert config_(id).enabled;

    // NONDET summary, which is sound because all non view functions in Morpho Blue are abstracted away.
    return (_, _);
}

function summaryWithdraw(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) returns (uint256, uint256) {
    assert shares == 0 <=> assets != 0;
    assert onBehalf == currentContract;
    assert receiver == currentContract;

    MetaMorphoHarness.Id id = Util.libId(marketParams);
    uint256 index = lastIndexWithdraw();
    requireInvariant inWithdrawQueueIsEnabled(index);

    // Check that all markets from which MetaMorpho withdraws are enabled markets.
    assert config_(id).enabled;

    // NONDET summary, which is sound because all non view functions in Morpho Blue are abstracted away.
    return (_, _);
}

// Check assertions in the summaries.
rule checkSummary(method f, env e, calldataarg args) {
    f(e, args);
    assert true;
}
