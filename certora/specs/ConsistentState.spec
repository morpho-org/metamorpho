// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function timelock() external returns (uint256) envfree;
    function fee() external returns (uint96) envfree;

    function maxFee() external returns (uint256) envfree;
    function minTimelock() external returns (uint256) envfree;
    function maxTimelock() external returns (uint256) envfree;
}

invariant feeInRange()
    assert_uint256(fee()) <= maxFee();

invariant timelockInRange()
    timelock() <= maxTimelock() && timelock() >= minTimelock();
