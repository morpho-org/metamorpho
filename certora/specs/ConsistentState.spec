// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function fee() external returns (uint96) envfree;
    function maxFee() external returns (uint256) envfree;
}

invariant feeInRange()
    assert_uint256(fee()) <= maxFee();
