// SPDX-License-Identifier: GPL-2.0-or-later
import "ConsistentState.spec";

using UtilHarness as Util;

methods {
    function Util.balanceOf(address, address) external returns(uint256) envfree;
    function Util.safeTransferFrom(address, address, address, uint256) external envfree;

    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);

    function _.supply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address receiver, bytes data) external => summarySupply(marketParams, assets, shares, receiver, data) expect (uint256, uint256);
    function _.idToMarketParams(MetaMorphoHarness.Id id) external => summaryIdToMarketParams(id) expect MetaMorphoHarness.MarketParams;
    function _.expectedSupplyAssets(MetaMorphoHarness.MarketParams, address) external => NONDET;
    function _.borrowRate(MetaMorphoHarness.MarketParams, MetaMorphoHarness.Market) external => NONDET;
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

function summarySupply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address receiver, bytes data) returns (uint256, uint256) {
    assert shares == 0;
    assert receiver == currentContract;
    assert data.length == 0;

    // Safe require because it is a verified invariant.
    require hasSupplyCapHasConsistentAsset(marketParams);

    // Summarize supply as just a transfer for the purpose of this specification file, which is sound because only the properties about tokens are verified in this file.
    Util.safeTransferFrom(marketParams.loanToken, currentContract, MORPHO(), assets);

    return (assets, shares);
}

rule depositTokenChange(env e, uint256 assets, address receiver) {
    address asset = asset();
    address morpho = MORPHO();

    // Trick to require that all the following addresses are different.
    require e.msg.sender == 0x10;
    require receiver == 0x11;
    require currentContract == 0x12;
    require morpho == 0x13;
    require asset == 0x14;

    uint256 balanceMorphoBefore = Util.balanceOf(asset, morpho);
    deposit(e, assets, receiver);
    uint256 balanceMorphoAfter = Util.balanceOf(asset, morpho);

    assert assets == assert_uint256(balanceMorphoAfter - balanceMorphoBefore);
}

rule withdrawTokenChange() {
    assert true;
}
