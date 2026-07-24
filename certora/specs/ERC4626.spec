// SPDX-License-Identifier: GPL-2.0-or-later

// ERC4626 round-trip properties (issue #333, a16z erc4626-tests/ERC4626.prop.sol
// L244-318): no round trip lets a user extract more value than they put in, e.g.
// redeem(deposit(a)) <= a and mint(withdraw(a)) >= a. The Morpho Blue- and
// fee-dependent totals are summarized to an arbitrary but fixed pair (a sound
// over-approximation that removes the Morpho Blue state and loop behind
// _accruedFeeShares), the decimals offset is fixed to 0 to keep
// 10 ** _decimalsOffset() concrete, and OZ's 512-bit mulDiv is replaced by its
// exact floor/ceil meaning.

methods {
    function convertToShares(uint256) external returns(uint256) envfree;
    function convertToAssets(uint256) external returns(uint256) envfree;
    function previewDeposit(uint256) external returns(uint256) envfree;
    function previewMint(uint256) external returns(uint256) envfree;
    function previewWithdraw(uint256) external returns(uint256) envfree;
    function previewRedeem(uint256) external returns(uint256) envfree;

    function MetaMorpho._accruedFeeShares() internal returns (uint256, uint256) => summaryAccruedFeeShares();
    function ERC4626._decimalsOffset() internal returns (uint8) => summaryDecimalsOffset();
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal returns (uint256) => cvlMulDiv(x, y, denominator, rounding);
}

ghost uint256 gTotalAssets;
ghost uint256 gFeeShares;

function summaryAccruedFeeShares() returns (uint256, uint256) {
    return (gFeeShares, gTotalAssets);
}

function summaryDecimalsOffset() returns uint8 {
    return 0;
}

function cvlMulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) returns uint256 {
    if (rounding == Math.Rounding.Ceil || rounding == Math.Rounding.Expand) {
        return require_uint256((x * y + (denominator - 1)) / denominator);
    } else {
        return require_uint256((x * y) / denominator);
    }
}

rule convertRoundTripAssets(uint256 assets) {
    assert convertToAssets(convertToShares(assets)) <= assets;
}

rule convertRoundTripShares(uint256 shares) {
    assert convertToShares(convertToAssets(shares)) <= shares;
}

rule roundTripDepositRedeem(uint256 assets) {
    assert previewRedeem(previewDeposit(assets)) <= assets;
}

rule roundTripDepositWithdraw(uint256 assets) {
    assert previewWithdraw(assets) >= previewDeposit(assets);
}

rule roundTripRedeemDeposit(uint256 shares) {
    assert previewDeposit(previewRedeem(shares)) <= shares;
}

rule roundTripRedeemMint(uint256 shares) {
    assert previewMint(shares) >= previewRedeem(shares);
}

rule roundTripMintWithdraw(uint256 shares) {
    assert previewWithdraw(previewMint(shares)) >= shares;
}

rule roundTripMintRedeem(uint256 shares) {
    assert previewRedeem(shares) <= previewMint(shares);
}

rule roundTripWithdrawMint(uint256 assets) {
    assert previewMint(previewWithdraw(assets)) >= assets;
}

rule roundTripWithdrawDeposit(uint256 assets) {
    assert previewDeposit(assets) <= previewWithdraw(assets);
}
