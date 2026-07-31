// SPDX-License-Identifier: GPL-2.0-or-later

// Intermediate lemma: prove that OpenZeppelin's real 512-bit `Math.mulDiv`
// returns the same VALUE as the basic floor/ceil `cvlMulDiv` used as a summary
// in ERC4626.spec. This discharges the `Math.mulDiv => cvlMulDiv` summary,
// turning it from an assumption into a proven-faithful abstraction.
//
// Safety only: we assert the returned value is correct ON THE NON-REVERTING
// PATH. We do NOT prove liveness (i.e. that mulDiv returns whenever the exact
// result fits in a uint256). `Math.mulDiv` is intentionally NOT summarized in
// this spec, so the real implementation is what gets verified.

methods {
    function mulDivWrapper(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding)
        external returns (uint256) envfree;
}

// Floor: rounds toward negative infinity == exact mathint floor of (x*y)/d.
rule mulDivFloorValue(uint256 x, uint256 y, uint256 d) {
    require d != 0;
    uint256 result = mulDivWrapper@withrevert(x, y, d, Math.Rounding.Floor);
    assert !lastReverted => result == require_uint256((x * y) / d);
}

// Trunc: for non-negative operands, truncation toward zero == floor.
rule mulDivTruncValue(uint256 x, uint256 y, uint256 d) {
    require d != 0;
    uint256 result = mulDivWrapper@withrevert(x, y, d, Math.Rounding.Trunc);
    assert !lastReverted => result == require_uint256((x * y) / d);
}

// Ceil: rounds toward positive infinity == exact mathint ceil of (x*y)/d.
rule mulDivCeilValue(uint256 x, uint256 y, uint256 d) {
    require d != 0;
    uint256 result = mulDivWrapper@withrevert(x, y, d, Math.Rounding.Ceil);
    assert !lastReverted => result == require_uint256((x * y + (d - 1)) / d);
}

// Expand: for non-negative operands, rounding away from zero == ceil.
rule mulDivExpandValue(uint256 x, uint256 y, uint256 d) {
    require d != 0;
    uint256 result = mulDivWrapper@withrevert(x, y, d, Math.Rounding.Expand);
    assert !lastReverted => result == require_uint256((x * y + (d - 1)) / d);
}
