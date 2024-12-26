// SPDX-License-Identifier: GPL-2.0-or-later
import "LastUpdated.spec";

methods {
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
    require lastUpdated > 0 => Util.libId(marketParams) == id;

    return marketParams;
}

function summarySupply(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, bytes data) returns (uint256, uint256) {
    assert shares == 0;
    assert onBehalf == currentContract;
    assert data.length == 0;

    requireInvariant supplyCapIsEnabled(Util.libId(marketParams));
    requireInvariant enabledHasConsistentAsset(marketParams);

    // Summarize supply as just a transfer for the purpose of this specification file, which is sound because only the properties about tokens are verified in this file.
    ERC20.safeTransferFrom(marketParams.loanToken, currentContract, MORPHO(), assets);

    return (assets, shares);
}

function summaryWithdraw(MetaMorphoHarness.MarketParams marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver) returns (uint256, uint256) {
    assert onBehalf == currentContract;
    assert receiver == currentContract;

    MetaMorphoHarness.Id id = Util.libId(marketParams);

    // Safe require because it is verified in MarketInteractions.
    require config_(id).enabled;
    requireInvariant enabledHasConsistentAsset(marketParams);

    // Use effective withdrawn assets if shares are given as input.
    uint256 withdrawn;
    if (shares == 0) {
        require withdrawn == assets;
    } else {
        uint256 totalAssets = Morpho.virtualTotalSupplyAssets(id);
        uint256 totalShares = Morpho.virtualTotalSupplyShares(id);
        require withdrawn == Util.libMulDivDown(shares, totalAssets, totalShares);
    }
    // Summarize withdraw as just a transfer for the purpose of this specification file, which is sound because only the properties about tokens are verified in this file.
    ERC20.safeTransferFrom(marketParams.loanToken, MORPHO(), currentContract, withdrawn);

    return (withdrawn, shares);
}

// Check balances change on deposit.
rule depositTokenChange(env e, uint256 assets, address receiver) {
    address asset = asset();
    address morpho = MORPHO();

    // Trick to require that all the following addresses are different.
    require morpho == 0x10;
    require asset == 0x11;
    require currentContract == 0x12;
    require e.msg.sender == 0x13;

    uint256 balanceMorphoBefore = ERC20.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoBefore = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderBefore = ERC20.balanceOf(asset, e.msg.sender);
    deposit(e, assets, receiver);
    uint256 balanceMorphoAfter = ERC20.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoAfter = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderAfter = ERC20.balanceOf(asset, e.msg.sender);

    assert assert_uint256(balanceMorphoAfter - balanceMorphoBefore) == assets;
    assert balanceMetaMorphoAfter == balanceMetaMorphoBefore;
    assert assert_uint256(balanceSenderBefore - balanceSenderAfter) == assets;
}

// Check balance changes on withdraw.
rule withdrawTokenChange(env e, uint256 assets, address receiver, address owner) {
    address asset = asset();
    address morpho = MORPHO();

    // Trick to require that all the following addresses are different.
    require morpho == 0x10;
    require asset == 0x11;
    require currentContract == 0x12;
    require receiver == 0x13;

    uint256 balanceMorphoBefore = ERC20.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoBefore = ERC20.balanceOf(asset, currentContract);
    uint256 balanceReceiverBefore = ERC20.balanceOf(asset, receiver);
    withdraw(e, assets, receiver, owner);
    uint256 balanceMorphoAfter = ERC20.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoAfter = ERC20.balanceOf(asset, currentContract);
    uint256 balanceReceiverAfter = ERC20.balanceOf(asset, receiver);

    assert assert_uint256(balanceMorphoBefore - balanceMorphoAfter) == assets;
    assert balanceMetaMorphoAfter == balanceMetaMorphoBefore;
    assert assert_uint256(balanceReceiverAfter - balanceReceiverBefore) == assets;
}

// Check that balances do not change on reallocate.
rule reallocateTokenChange(env e, MetaMorphoHarness.MarketAllocation[] allocations) {
    address asset = asset();
    address morpho = MORPHO();

    // Trick to require that all the following addresses are different.
    require morpho == 0x10;
    require asset == 0x11;
    require currentContract == 0x12;

    uint256 balanceMorphoBefore = ERC20.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoBefore = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderBefore = ERC20.balanceOf(asset, e.msg.sender);
    reallocate(e, allocations);
    uint256 balanceMorphoAfter = ERC20.balanceOf(asset, morpho);
    uint256 balanceMetaMorphoAfter = ERC20.balanceOf(asset, currentContract);
    uint256 balanceSenderAfter = ERC20.balanceOf(asset, e.msg.sender);

    assert balanceMorphoAfter == balanceMorphoAfter;
    assert balanceMetaMorphoAfter == balanceMetaMorphoBefore;
    assert balanceSenderAfter == balanceSenderBefore;
}
