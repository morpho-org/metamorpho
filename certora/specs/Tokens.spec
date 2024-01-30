// SPDX-License-Identifier: GPL-2.0-or-later
using UtilHarness as Util;

methods {
    function asset() external returns(address) envfree;
    function MORPHO() external returns(address) envfree;

    function Util.balanceOf(address, address) external returns(uint256) envfree;
    function Util.transferFrom(address, address, address, uint256) external envfree;

    function _.supply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address receiver, bytes data) external => summarySupply(marketParams, assets, shares, receiver, data) expect (uint256, uint256);

    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);
}

function summarySupply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address receiver, bytes data) returns (uint256, uint256) {
    require shares == 0;
    require receiver == currentContract;
    require data.length == 0;

    Util.transferFrom(marketParams.loanToken, currentContract, MORPHO(), assets);

    return (assets, shares);
}

rule depositTokenChange(env e, uint256 assets, address receiver) {
    address asset = asset();
    address morpho = MORPHO();

    require morpho != currentContract;

    uint256 balanceMorphoBefore = Util.balanceOf(asset, morpho);
    deposit(e, assets, receiver);
    uint256 balanceMorphoAfter = Util.balanceOf(asset, morpho);

    assert assets == assert_uint256(balanceMorphoAfter - balanceMorphoBefore);
}

rule withdrawTokenChange() {
    assert true;
}
