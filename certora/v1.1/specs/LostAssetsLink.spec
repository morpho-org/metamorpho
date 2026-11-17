// SPDX-License-Identifier: GPL-2.0-or-later

using MorphoHarness as Morpho;
using Util as Util;

methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function lostAssets() external returns(uint256) envfree;
    function totalAssets() external returns(uint256) envfree;
    function totalSupply() external returns(uint256) envfree;
    function lastTotalAssets() external returns(uint256) envfree;
    function realTotalAssets() external returns(uint256) envfree;
    function newLostAssets() external returns(uint256) envfree;
    function MORPHO() external returns(address) envfree;

    // Summaries.
    function _.expectedSupplyAssets(MorphoHarness.MarketParams marketParams, address user) external => summaryExpectedSupplyAssets(marketParams, user) expect (uint256);
    function _.idToMarketParams(MetaMorphoHarness.Id id) external => summaryIdToMarketParams(id) expect MetaMorphoHarness.MarketParams ALL;

    // We assume that the erc20 is view since what happens in the token is not relevant.
    function _.transfer(address, uint256) external => NONDET;
    function _.transferFrom(address, address, uint256) external => NONDET;
    function _.balanceOf(address) external => NONDET;

    // The IRM and oracle are view.
    function _.borrowRate(MorphoHarness.MarketParams, MorphoHarness.Market) external => NONDET;
    function _.price() external => NONDET;

    // We assume that there are no callbacks.
    function _.onMorphoSupply(uint256, bytes) external => NONDET;
    function _.onMorphoRepay(uint256, bytes) external => NONDET;
    function _.onMorphoSupplyCollateral(uint256, bytes) external => NONDET;
    function _.onMorphoLiquidate(uint256, bytes) external => NONDET;
    function _.onMorphoFlashLoan(uint256, bytes) external => NONDET;

    function Morpho.supplyShares(MorphoHarness.Id, address) external returns uint256 envfree;
    function Morpho.virtualTotalSupplyAssets(MorphoHarness.Id) external returns uint256 envfree;
    function Morpho.virtualTotalSupplyShares(MorphoHarness.Id) external returns uint256 envfree;

    function Util.libId(MetaMorphoHarness.MarketParams) external returns(MetaMorphoHarness.Id) envfree;
}

ghost ghostExpectedSupply(address, address, address, address, uint256, address) returns uint256;

function summaryExpectedSupplyAssets(MorphoHarness.MarketParams marketParams, address user) returns uint256 {
    return ghostExpectedSupply(marketParams.loanToken, marketParams.collateralToken, marketParams.oracle, marketParams.irm, marketParams.lltv, user);
}

function summaryIdToMarketParams(MetaMorphoHarness.Id id) returns MetaMorphoHarness.MarketParams {
    MetaMorphoHarness.MarketParams marketParams;

    // Safe require because:
    // - markets in the supply/withdraw queue have positive lastUpdate (see LastUpdated.spec)
    // - lastUpdate(id) > 0 => marketParams.id() == id is a verified invariant in Morpho Blue.
    require Util.libId(marketParams) == id;

    return marketParams;
}

// Note that it implies newLostAssets <= totalAssets.
// Note that it implies realTotalAssets + lostAssets = lastTotalAssets after accrueInterest().
rule realPlusLostEqualsTotal() {
    assert realTotalAssets() + newLostAssets() == totalAssets();
}
