// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;
}

persistent ghost bool delegateCall;

hook DELEGATECALL(uint g, address addr, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    delegateCall = true;
}

// Check that the contract is truly immutable.
rule noDelegateCalls(method f, env e, calldataarg data) {
    // Set up the initial state.
    require !delegateCall;
    f(e,data);
    assert !delegateCall;
}
