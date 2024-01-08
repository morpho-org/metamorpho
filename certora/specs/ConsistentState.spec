// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function pendingTimelock() external returns(uint192, uint64) envfree;
    function timelock() external returns (uint256) envfree;
    function fee() external returns (uint96) envfree;

    function maxFee() external returns (uint256) envfree;
    function minTimelock() external returns (uint256) envfree;
    function maxTimelock() external returns (uint256) envfree;
}

invariant feeInRange()
    assert_uint256(fee()) <= maxFee();

function isPendingTimelockInRange() returns bool {
    uint192 value;
    uint64 validAt;
    value, validAt = pendingTimelock();

    return validAt != 0 => assert_uint256(value) <= maxTimelock() && assert_uint256(value) >= minTimelock();
}

invariant pendingTimelockInRange()
    isPendingTimelockInRange();

invariant timelockInRange()
    timelock() <= maxTimelock() && timelock() >= minTimelock()
{
    preserved {
        require isPendingTimelockInRange();
    }
}
