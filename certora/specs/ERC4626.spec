// SPDX-License-Identifier: GPL-2.0-or-later

// Verification of the ERC4626 round-trip properties (formal-verification wish
// list, issue #333: a16z erc4626-tests/ERC4626.prop.sol L244-318). The
// round-trip properties state that no round trip lets a user extract more value
// than they put in: e.g. redeem(deposit(a)) <= a, mint(withdraw(a)) >= a, etc.
//
// Modeling choice (documented, see the accompanying report).
// MetaMorpho.totalAssets() sums MORPHO.expectedSupplyAssets over the whole
// withdrawQueue and, together with the performance-fee accrual, makes every
// conversion depend on Morpho Blue state through a loop -- the source of the
// timeouts seen in #419. That dependency has a single funnel in the conversion
// path: the internal _accruedFeeShares(), which is the only place
// convert*/preview* read totalAssets() and the fee. We summarize it to return
// an arbitrary but fixed pair of totals (gFeeShares, gTotalAssets). This is a
// SOUND over-approximation: we prove the inequalities for every possible pair
// of totals, hence in particular for the real ones. It also makes the
// conversions pure arithmetic over fixed virtual totals, with no Morpho Blue
// state and no loop.
//
// We additionally fix the decimals offset to 0 (an 18-decimals underlying, the
// DECIMALS_OFFSET == 0 case) so that `10 ** _decimalsOffset()` stays concrete
// for the SMT solver. The round-trip inequalities are offset-independent, so
// this is a tractability scoping, not a correctness assumption; generalizing to
// a symbolic offset is a documented follow-up.
//
// At fixed totals the shares/assets returned by deposit/mint/withdraw/redeem
// equal the corresponding preview* quotes: each entry point computes its result
// with the same _convertTo{Shares,Assets}WithTotals and the rounding
// deposit = Floor, mint = Ceil, withdraw = Ceil, redeem = Floor. We therefore
// verify each a16z round trip on the preview* composition at fixed totals,
// which isolates exactly the rounding-direction correctness that guarantees no
// round-trip profit. The fully stateful composition (calling deposit then
// redeem with the totals updating in between) additionally requires Morpho
// Blue's supply accounting and is left to iterate against CI.

methods {
    function convertToShares(uint256) external returns(uint256) envfree;
    function convertToAssets(uint256) external returns(uint256) envfree;
    function previewDeposit(uint256) external returns(uint256) envfree;
    function previewMint(uint256) external returns(uint256) envfree;
    function previewWithdraw(uint256) external returns(uint256) envfree;
    function previewRedeem(uint256) external returns(uint256) envfree;

    // Cut the Morpho Blue-dependent, fee-dependent totals to fixed ghosts (see header).
    function _accruedFeeShares() internal returns (uint256, uint256) => summaryAccruedFeeShares();
    // Keep `10 ** _decimalsOffset()` concrete for the SMT solver (see header).
    function _decimalsOffset() internal returns (uint8) => summaryDecimalsOffset();
    // Replace OZ's 512-bit assembly mulDiv (which the conversions use, and which
    // the SMT solver cannot reason about for these lemmas) by its exact
    // mathematical meaning. Sound: cvlMulDiv is floor/ceil of x*y/denominator.
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal returns (uint256) => cvlMulDiv(x, y, denominator, rounding);
}

// Arbitrary but fixed virtual totals shared by every conversion in a rule.
ghost uint256 gTotalAssets;
ghost uint256 gFeeShares;

function summaryAccruedFeeShares() returns (uint256, uint256) {
    return (gFeeShares, gTotalAssets);
}

function summaryDecimalsOffset() returns uint8 {
    return 0;
}

// Exact floor/ceil semantics of x * y / denominator. `require_uint256` models
// OZ mulDiv reverting when the result does not fit in a uint256; all call sites
// here have denominator >= 1 (newTotalAssets + 1, newTotalSupply + 1).
function cvlMulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) returns uint256 {
    if (rounding == Math.Rounding.Ceil || rounding == Math.Rounding.Expand) {
        return require_uint256((x * y + (denominator - 1)) / denominator);
    } else {
        return require_uint256((x * y) / denominator);
    }
}

// convertToAssets is a left inverse of convertToShares up to rounding: converting
// assets to shares and back never yields more assets than you started with.
rule convertRoundTripAssets(uint256 assets) {
    uint256 shares = convertToShares(assets);
    uint256 assets2 = convertToAssets(shares);
    assert assets2 <= assets;
}

// Symmetric conversion lemma for shares.
rule convertRoundTripShares(uint256 shares) {
    uint256 assets = convertToAssets(shares);
    uint256 shares2 = convertToShares(assets);
    assert shares2 <= shares;
}

// a16z prop_RT_deposit_redeem (L249-255): redeem(deposit(a)) <= a.
rule roundTripDepositRedeem(uint256 assets) {
    uint256 shares = previewDeposit(assets);
    uint256 assets2 = previewRedeem(shares);
    assert assets2 <= assets;
}

// a16z prop_RT_deposit_withdraw (L257-265): the shares burned by withdraw(a) are
// at least the shares minted by deposit(a).
rule roundTripDepositWithdraw(uint256 assets) {
    uint256 shares1 = previewDeposit(assets);
    uint256 shares2 = previewWithdraw(assets);
    assert shares2 >= shares1;
}

// a16z prop_RT_redeem_deposit (L267-273): deposit(redeem(s)) <= s.
rule roundTripRedeemDeposit(uint256 shares) {
    uint256 assets = previewRedeem(shares);
    uint256 shares2 = previewDeposit(assets);
    assert shares2 <= shares;
}

// a16z prop_RT_redeem_mint (L275-283): the assets paid by mint(s) are at least
// the assets returned by redeem(s).
rule roundTripRedeemMint(uint256 shares) {
    uint256 assets1 = previewRedeem(shares);
    uint256 assets2 = previewMint(shares);
    assert assets2 >= assets1;
}

// a16z prop_RT_mint_withdraw (L285-291): withdraw(mint(s)) >= s.
rule roundTripMintWithdraw(uint256 shares) {
    uint256 assets = previewMint(shares);
    uint256 shares2 = previewWithdraw(assets);
    assert shares2 >= shares;
}

// a16z prop_RT_mint_redeem (L293-301): the assets returned by redeem(s) are at
// most the assets paid by mint(s).
rule roundTripMintRedeem(uint256 shares) {
    uint256 assets1 = previewMint(shares);
    uint256 assets2 = previewRedeem(shares);
    assert assets2 <= assets1;
}

// a16z prop_RT_withdraw_mint (L303-309): mint(withdraw(a)) >= a.
rule roundTripWithdrawMint(uint256 assets) {
    uint256 shares = previewWithdraw(assets);
    uint256 assets2 = previewMint(shares);
    assert assets2 >= assets;
}

// a16z prop_RT_withdraw_deposit (L311-318): the shares minted by deposit(a) are
// at most the shares burned by withdraw(a).
rule roundTripWithdrawDeposit(uint256 assets) {
    uint256 shares1 = previewWithdraw(assets);
    uint256 shares2 = previewDeposit(assets);
    assert shares2 <= shares1;
}
