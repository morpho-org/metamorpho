// SPDX-License-Identifier: GPL-2.0-or-later

// Intermediate lemma: prove that OpenZeppelin's real 512-bit `Math.mulDiv`
// rounds exactly like the basic floor/ceil `cvlMulDiv` used as a summary in
// ERC4626.spec. This discharges the `Math.mulDiv => cvlMulDiv` summary,
// turning it from an assumption into a proven-faithful abstraction.
//
// Strength: instead of a single mathint-division equality
// (`res == (x*y)/d`), which forces the SMT solver to reason about division of
// a 512-bit product and tends to time out, we prove the two TIGHT two-sided
// multiplicative bounds that together UNIQUELY pin the returned value:
//   Floor: res*d <= x*y  AND  (res+1)*d > x*y   <=>  res == floor(x*y/d)
//   Ceil : res*d >= x*y  AND  (res>0 => (res-1)*d < x*y)  <=>  res == ceil(x*y/d)
// All arithmetic below is over CVL `mathint` (uint256 operands auto-promote),
// so `x*y`, `res*d`, `(res+1)*d` are exact and never overflow. This is the
// same bounds-based structure used to discharge mulDiv ghost summaries in
// morpho-org/midnight's `certora/specs/MulDiv.spec`.
//
// Safety only, revert-preserving: `Math.mulDiv` is intentionally NOT summarized
// here (the real implementation is verified), the call uses `@withrevert`, and
// every bound is asserted ONLY on the non-reverting path (`!lastReverted =>`).
// We do NOT prove liveness (that it returns whenever the exact result fits).
// This matches Mathis's "safety, not liveness".

methods {
    function mulDivWrapper(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding)
        external returns (uint256) envfree;
}

// Floor: rounds toward negative infinity == exact mathint floor of (x*y)/d.
rule mulDivFloorValue(uint256 x, uint256 y, uint256 d) {
    require d != 0;
    uint256 res = mulDivWrapper@withrevert(x, y, d, Math.Rounding.Floor);
    assert !lastReverted => res * d <= x * y;
    assert !lastReverted => (res + 1) * d > x * y;
}

// Trunc: for non-negative operands, truncation toward zero == floor.
rule mulDivTruncValue(uint256 x, uint256 y, uint256 d) {
    require d != 0;
    uint256 res = mulDivWrapper@withrevert(x, y, d, Math.Rounding.Trunc);
    assert !lastReverted => res * d <= x * y;
    assert !lastReverted => (res + 1) * d > x * y;
}

// Ceil: rounds toward positive infinity == exact mathint ceil of (x*y)/d.
rule mulDivCeilValue(uint256 x, uint256 y, uint256 d) {
    require d != 0;
    uint256 res = mulDivWrapper@withrevert(x, y, d, Math.Rounding.Ceil);
    assert !lastReverted => res * d >= x * y;
    assert !lastReverted => (res > 0 => (res - 1) * d < x * y);
}

// Expand: for non-negative operands, rounding away from zero == ceil.
rule mulDivExpandValue(uint256 x, uint256 y, uint256 d) {
    require d != 0;
    uint256 res = mulDivWrapper@withrevert(x, y, d, Math.Rounding.Expand);
    assert !lastReverted => res * d >= x * y;
    assert !lastReverted => (res > 0 => (res - 1) * d < x * y);
}
