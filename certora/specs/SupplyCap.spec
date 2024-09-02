// SPDX-License-Identifier: GPL-2.0-or-later

using MorphoHarness as Morpho;
using Util as Util;

methods {
    function MORPHO() external returns(address) envfree;
    function config_(MetaMorphoHarness.Id) external returns(MetaMorphoHarness.MarketConfig) envfree;

    function Morpho.idToMarketParams(MetaMorphoHarness.Id) external returns(address, address, address, address, uint256) envfree;
    function Morpho.lastUpdate(MetaMorphoHarness.Id) external returns(uint256) envfree;
    function Morpho.supplyShares(MetaMorphoHarness.Id, address) external returns(uint256) envfree;
    function Morpho.totalSupplyAssets(MetaMorphoHarness.Id) external returns(uint256) envfree;
    function Morpho.totalSupplyShares(MetaMorphoHarness.Id) external returns(uint256) envfree;

    function Util.libId(MetaMorphoHarness.MarketParams) external returns(MetaMorphoHarness.Id) envfree;
    function Util.toAssetsDown(uint256, uint256, uint256) external returns(uint256) envfree;

    function _.expectedSupplyAssets(MetaMorphoHarness.Id id, address user) external => supplyAssets(id, user) expect(uint256);

    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
}

hook Sload uint184 cap config[KEY MetaMorphoHarness.Id id].cap {
    address loanToken; address collateralToken; address oracle; address irm; uint256 lltv;
    (loanToken, collateralToken, oracle, irm, lltv) = Morpho.idToMarketParams(id);

    MetaMorphoHarness.MarketParams marketParams;
    require loanToken == marketParams.loanToken;
    require collateralToken == marketParams.collateralToken;
    require oracle == marketParams.oracle;
    require irm == marketParams.irm;
    require lltv == marketParams.lltv;

    require Util.libId(marketParams) == id;
}

function supplyAssets(MetaMorphoHarness.Id id, address user) returns uint256 {
    uint256 shares = Morpho.supplyShares(id, user);
    uint256 totalSupplyAssets = Morpho.totalSupplyAssets(id);
    uint256 totalSupplyShares = Morpho.totalSupplyShares(id);
    require shares <= totalSupplyShares;
    return Util.toAssetsDown(shares, totalSupplyAssets, totalSupplyShares);
}

rule respectSupplyCap(method f, env e, calldataarg args)
{
    MetaMorphoHarness.MarketParams marketParams;
    MetaMorphoHarness.Id id = Util.libId(marketParams);

    address morpho = MORPHO();
    uint256 cap = config_(id).cap;

    require Morpho.lastUpdate(id) == e.block.timestamp;

    require supplyAssets(id, currentContract) <= cap;

    f(e, args);
    require assert_uint256(config_(id).cap) == cap;

    assert supplyAssets(id, currentContract) <= cap;
}
