// SPDX-License-Identifier: GPL-2.0-or-later
import "ConsistentState.spec";

using UtilHarness as Util;

methods {
    function Util.balanceOf(address, address) external returns(uint256) envfree;
    function Util.safeTransferFrom(address, address, address, uint256) external envfree;

    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);

    function _.supply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) external => summarySupply(marketParams, assets, shares, onBehalf, data) expect (uint256, uint256) ALL;
    function _.withdraw(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external => summaryWithdraw(marketParams, assets, shares, onBehalf, receiver) expect (uint256, uint256) ALL;
    function _.idToMarketParams(MetaMorphoHarness.Id id) external => summaryIdToMarketParams(id) expect MetaMorphoHarness.MarketParams ALL;

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

function summarySupply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) returns (uint256, uint256) {
    assert shares == 0;
    assert onBehalf == currentContract;
    assert data.length == 0;

    // Safe require because it is a verified invariant.
    require hasSupplyCapIsEnabled(Morpho.libId(marketParams));
    // Safe require because it is a verified invariant.
    require isEnabledHasConsistentAsset(marketParams);

    // Summarize supply as just a transfer for the purpose of this specification file, which is sound because only the properties about tokens are verified in this file.
    Util.safeTransferFrom(marketParams.loanToken, currentContract, MORPHO(), assets);

    return (assets, shares);
}

function summaryWithdraw(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) returns (uint256, uint256) {
    assert onBehalf == currentContract;
    assert receiver == currentContract;

    MetaMorphoHarness.Id id = Morpho.libId(marketParams);
    uint256 withdrawn = Util.withdrawnAssets(MORPHO(), id, assets, shares);

    bool enabled;
    _, enabled, _ = config(id);
    // Safe require because:
    // - for reallocate this is checked in the code
    // - for withdraw, it is verified that markets in the withdraw queue are enabled.
    require enabled;
    // Safe require because it is a verified invariant.
    require isEnabledHasConsistentAsset(marketParams);

    // Summarize supply as just a transfer for the purpose of this specification file, which is sound because only the properties about tokens are verified in this file.
    Util.safeTransferFrom(marketParams.loanToken, MORPHO(), currentContract, withdrawn);

    return (withdrawn, shares);
}

rule depositTokenChange(env e, uint256 assets, address receiver) {
    address asset = asset();
    address morpho = MORPHO();

    // Trick to require that all the following addresses are different.
    require morpho == 0x10;
    require asset == 0x11;
    require currentContract == 0x12;
    require e.msg.sender == 0x13;
    require receiver == 0x14;

    uint256 balanceMorphoBefore = Util.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoBefore = Util.balanceOf(asset, currentContract);
    deposit(e, assets, receiver);
    uint256 balanceMorphoAfter = Util.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoAfter = Util.balanceOf(asset, currentContract);

    assert assert_uint256(balanceMorphoAfter - balanceMorphoBefore) == assets;
    assert balanceMetaMorphoAfter == balanceMetaMorphoBefore;
}

rule withdrawTokenChange(env e, uint256 assets, address receiver, address owner) {
    address asset = asset();
    address morpho = MORPHO();

    // Trick to require that all the following addresses are different.
    require morpho == 0x10;
    require asset == 0x11;
    require currentContract == 0x12;
    require e.msg.sender == 0x13;
    require receiver == 0x14;
    require owner == 0x15;

    uint256 balanceMorphoBefore = Util.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoBefore = Util.balanceOf(asset, currentContract);
    withdraw(e, assets, receiver, owner);
    uint256 balanceMorphoAfter = Util.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoAfter = Util.balanceOf(asset, currentContract);

    assert assert_uint256(balanceMorphoBefore - balanceMorphoAfter) == assets;
    assert balanceMetaMorphoAfter == balanceMetaMorphoBefore;
}

rule reallocateTokenChange(env e, MetaMorphoHarness.MarketAllocation[] allocations) {
    address asset = asset();
    address morpho = MORPHO();

    // Trick to require that all the following addresses are different.
    require morpho == 0x10;
    require asset == 0x11;
    require currentContract == 0x12;
    require e.msg.sender == 0x13;

    uint256 balanceMorphoBefore = Util.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoBefore = Util.balanceOf(asset, currentContract);
    reallocate(e, allocations);
    uint256 balanceMorphoAfter = Util.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoAfter = Util.balanceOf(asset, currentContract);

    assert balanceMorphoAfter == balanceMorphoAfter;
    assert balanceMetaMorphoAfter == balanceMetaMorphoBefore;
}
