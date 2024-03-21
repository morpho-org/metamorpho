// SPDX-License-Identifier: GPL-2.0-or-later
import "Enabled.spec";

using MorphoHarness as Morpho;

methods {
    function Morpho.supply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) external returns (uint256, uint256) => summarySupply(marketParams, assets, shares, onBehalf, data);
    function Morpho.withdraw(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) external returns (uint256, uint256) => summaryWithdraw(marketParams, assets, shares, onBehalf, receiver);
    function Morpho.libId(MorphoHarness.MarketParams) external returns(MorphoHarness.Id) envfree;
}

function summarySupply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) returns(uint256, uint256) {
    assert shares == 0;
    assert onBehalf == currentContract;
    assert data.length == 0;

    // What environment parameter should I give ?
    return Morpho.supply(marketParams, assets, shares, onBehalf, data);
    // Compile using the following line instead
    // return (assets, shares);
}

function summaryWithdraw(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) returns (uint256, uint256) {
    assert onBehalf == currentContract;
    assert receiver == currentContract;

    // What environment parameter should I give ?
    return Morpho.withdraw(marketParams, assets, shares, onBehalf, receiver);
    // Compile using the following line instead
    // return (assets, shares);
}

invariant checkSummaries()
    true;
