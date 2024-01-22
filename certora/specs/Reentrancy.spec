// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;
}

persistent ghost bool delegateCall;
persistent ghost bool callToMorpho;
// True when storage has been accessed with either a SSTORE or a SLOAD.
persistent ghost bool hasAccessedStorage;
// True when a CALL has been done after storage has been accessed.
persistent ghost bool hasCallAfterAccessingStorage;
// True when storage has been accessed, after which an external call is made, followed by accessing storage again.
persistent ghost bool hasReentrancyUnsafeCall;

function summaryCallToMorpho() {
    callToMorpho = true;
}

hook ALL_SSTORE(uint loc, uint v) {
    hasAccessedStorage = true;
    hasReentrancyUnsafeCall = hasCallAfterAccessingStorage;
}

hook ALL_SLOAD(uint loc) uint v {
    hasAccessedStorage = true;
    hasReentrancyUnsafeCall = hasCallAfterAccessingStorage;
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (callToMorpho) {
        // Assume that calls to Morpho markets are trusted (as they have gone through a timelock).
        callToMorpho = false;
    } else {
        hasCallAfterAccessingStorage = hasAccessedStorage;
    }
}

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    delegateCall = true;
}

// Check that no function is accessing storage, then making an external CALL, and accessing storage again.
rule reentrancySafe(method f, env e, calldataarg data) {
    // Set up the initial state.
    require !callToMorpho;
    require !hasAccessedStorage && !hasCallAfterAccessingStorage && !hasReentrancyUnsafeCall;
    f(e,data);
    assert !hasReentrancyUnsafeCall;
}

// Check that the contract is truly immutable.
rule noDelegateCalls(method f, env e, calldataarg data) {
    // Set up the initial state.
    require !delegateCall;
    f(e,data);
    assert !delegateCall;
}
