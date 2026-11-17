// SPDX-License-Identifier: GPL-2.0-or-later

methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function lostAssets() external returns(uint256) envfree;
    function totalAssets() external returns(uint256) envfree;
    function totalSupply() external returns(uint256) envfree;
    function lastTotalAssets() external returns(uint256) envfree;
    function realTotalAssets() external returns(uint256) envfree;
    function fee() external returns(uint96) envfree;
    function maxFee() external returns(uint256) envfree;
    function DECIMALS_OFFSET() external returns(uint8) envfree;

    // We assume that Morpho and the ERC20s can't reenter Metamorpho.
    function _.supply(MetaMorphoHarness.MarketParams, uint256, uint256, address, bytes) external => NONDET;
    function _.withdraw(MetaMorphoHarness.MarketParams, uint256, uint256, address, address) external => NONDET;
    function _.accrueInterest(MetaMorphoHarness.MarketParams) external => NONDET;
    function _.idToMarketParams(MetaMorphoHarness.Id) external => NONDET;
    function _.supplyShares(MetaMorphoHarness.Id, address) external => NONDET;
    function _.expectedSupplyAssets(MetaMorphoHarness.MarketParams, address) external => CONSTANT;
    function _.market(MetaMorphoHarness.Id) external => NONDET;

    function _.transfer(address, uint256) external => NONDET;
    function _.transferFrom(address, address, uint256) external => NONDET;
    function _.balanceOf(address) external => NONDET;

    // Summarise mulDiv because its implementation is too complex.
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal => summaryMulDiv(x, y, denominator, rounding) expect (uint256);
}

function summaryMulDiv(uint256 x, uint256 y, uint256 d, Math.Rounding rounding) returns uint256 {
    if (rounding == Math.Rounding.Floor) {
        // Safe require because the reference implementation would revert.
        return require_uint256((x * y) / d);
    } else {
        // Safe require because the reference implementation would revert.
        return require_uint256((x * y + (d - 1)) / d);
    }
}

// Check that the lost assets always increase.
rule lostAssetsIncreases(method f, env e, calldataarg args) {
    uint256 lostAssetsBefore = lostAssets();

    f(e, args);

    uint256 lostAssetsAfter = lostAssets();

    assert lostAssetsBefore <= lostAssetsAfter;
}

// Check that the last total assets are smaller than the total assets.
rule lastTotalAssetsSmallerThanTotalAssets() {
    assert lastTotalAssets() <= totalAssets();
}

// Check that the last total assets increase except on withdrawal and redeem.
rule lastTotalAssetsIncreases(method f, env e, calldataarg args)
filtered {
    f -> f.selector != sig:withdraw(uint256, address, address).selector &&
        f.selector != sig:redeem(uint256, address, address).selector &&
        f.selector != sig:updateWithdrawQueue(uint256[]).selector
}
{
    uint256 lastTotalAssetsBefore = lastTotalAssets();

    f(e, args);

    uint256 lastTotalAssetsAfter = lastTotalAssets();

    assert lastTotalAssetsBefore <= lastTotalAssetsAfter;
}

// Check that the last total assets decreases on withdraw.
rule lastTotalAssetsDecreasesCorrectlyOnWithdraw(env e, uint256 assets, address receiver, address owner) {
    uint256 lastTotalAssetsBefore = lastTotalAssets();

    withdraw(e, assets, receiver, owner);

    uint256 lastTotalAssetsAfter = lastTotalAssets();

    assert to_mathint(lastTotalAssetsAfter) >= lastTotalAssetsBefore - assets;
}

// Check that the last total assets decreases on redeem.
rule lastTotalAssetsDecreasesCorrectlyOnRedeem(env e, uint256 shares, address receiver, address owner) {
    uint256 lastTotalAssetsBefore = lastTotalAssets();

    uint256 assets = redeem(e, shares, receiver, owner);

    uint256 lastTotalAssetsAfter = lastTotalAssets();

    assert to_mathint(lastTotalAssetsAfter) >= lastTotalAssetsBefore - assets;
}

persistent ghost mathint sumBalances {
    init_state axiom sumBalances == 0;
}

hook Sload uint256 balance _balances[KEY address addr] {
    require sumBalances >= to_mathint(balance);
}

hook Sstore _balances[KEY address user] uint256 newBalance (uint256 oldBalance) {
    sumBalances = sumBalances + newBalance - oldBalance;
}

// Check that the total supply is the sum of the balances.
strong invariant totalIsSumBalances()
    to_mathint(totalSupply()) == sumBalances;

// Check that the share price does not decrease lower than the one at the last interaction.
rule sharePriceIncreases(method f, env e, calldataarg args) {
    requireInvariant totalIsSumBalances();
    require assert_uint256(fee()) == 0;

    // We query them in a state in which the vault is sync.
    uint256 lastTotalAssetsBefore = lastTotalAssets();
    uint256 totalSupplyBefore = totalSupply();
    require totalSupplyBefore > 0;

    f(e, args);

    uint256 totalAssetsAfter = lastTotalAssets();
    uint256 totalSupplyAfter = totalSupply();
    require totalSupplyAfter > 0;

    uint256 decimalsOffset = assert_uint256(DECIMALS_OFFSET());
    require decimalsOffset == 18;

    assert (lastTotalAssetsBefore + 1) * (totalSupplyAfter + 10^decimalsOffset) <= (totalAssetsAfter + 1) * (totalSupplyBefore + 10^decimalsOffset);
}
