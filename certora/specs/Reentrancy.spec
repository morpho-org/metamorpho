// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function _.accrueInterest(MetaMorphoHarness.MarketParams) external => voidSummary() expect void;
    function _.supply(MetaMorphoHarness.MarketParams, uint256, uint256, address, bytes) external => uintPairSummary() expect (uint256, uint256);
    function _.withdraw(MetaMorphoHarness.MarketParams, uint256, uint256, address, address) external => uintPairSummary() expect (uint256, uint256);

    function _.transferFrom(address, address, uint256) external => boolSummary() expect bool;
    function _.balanceOf(address) external => uintSummary() expect uint256;
}

function voidSummary() {
    ignoredCall = true;
}

function uintSummary() returns uint256 {
    ignoredCall = true;
    uint256 value;
    return value;
}

function uintPairSummary() returns (uint256, uint256) {
    ignoredCall = true;
    uint256 firstValue;
    uint256 secondValue;
    return (firstValue, secondValue);
}

function boolSummary() returns bool {
    ignoredCall = true;
    bool value;
    return value;
}

persistent ghost bool ignoredCall;
// True when storage has been accessed with either a SSTORE or a SLOAD.
persistent ghost bool hasAccessedStorage;
// True when a CALL has been done after storage has been accessed.
persistent ghost bool hasCallAfterAccessingStorage;
// True when storage has been accessed, after which an external call is made, followed by accessing storage again.
persistent ghost bool hasReentrancyUnsafeCall;

hook ALL_SSTORE(uint loc, uint v) {
    hasAccessedStorage = true;
    hasReentrancyUnsafeCall = hasCallAfterAccessingStorage;
}

hook ALL_SLOAD(uint loc) uint v {
    hasAccessedStorage = true;
    hasReentrancyUnsafeCall = hasCallAfterAccessingStorage;
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (ignoredCall) {
        // Assume that calls to Morpho markets and tokens are trusted (as they have gone through a timelock).
        ignoredCall = false;
    } else {
        hasCallAfterAccessingStorage = hasAccessedStorage;
    }
}

// Check that no function is accessing storage, then making an external CALL, and accessing storage again.
rule reentrancySafe(method f, env e, calldataarg data) {
    // Set up the initial state.
    require !ignoredCall;
    require !hasAccessedStorage && !hasCallAfterAccessingStorage && !hasReentrancyUnsafeCall;
    f(e,data);
    assert !hasReentrancyUnsafeCall;
}
