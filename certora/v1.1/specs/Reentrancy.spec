// SPDX-License-Identifier: GPL-2.0-or-later
methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function _.accrueInterest(MetaMorphoHarness.MarketParams) external => voidSummary() expect void;
    function _.supply(MetaMorphoHarness.MarketParams, uint256, uint256, address, bytes) external => uintPairSummary() expect (uint256, uint256);
    function _.withdraw(MetaMorphoHarness.MarketParams, uint256, uint256, address, address) external => uintPairSummary() expect (uint256, uint256);

    function _.transfer(address, uint256) external => boolSummary() expect bool;
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
persistent ghost bool hasCall;

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (ignoredCall) {
        // Ignore calls to tokens and Morpho markets as they are trusted (they have gone through a timelock).
        ignoredCall = false;
    } else {
        hasCall = true;
    }
}

// Check that there are no untrusted external calls, ensuring notably reentrancy safety.
rule reentrancySafe(method f, env e, calldataarg data) {
    // Set up the initial state.
    require !ignoredCall && !hasCall;
    f(e,data);
    assert !hasCall;
}
