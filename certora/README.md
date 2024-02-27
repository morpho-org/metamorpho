This folder contains the verification of MetaMorpho using CVL, Certora's Verification Language.

# High-level description

A MetaMorpho vault is an ERC4626 vault that defines a list of Morpho Blue markets to allocate its funds.
See [`README.md`](../README.md) for a in depth description of MetaMorpho.

## Roles

MetaMorpho defines different roles to be able to manage the vault, the distinction between roles helps in reducing trust assumptions.
Roles follow a hierarchy, and this hierarchy is verified to hold in [`Roles.spec`](specs/Roles.spec).
More precisely, a stronger role is checked to be able to do the same operations of a lesser role.
Additionally, it is verified in [`Reverts.spec`](specs/Reverts.spec) that the roles are necessary to be able to do permissioned operations
For example, the following rule makes sure that having the guardian role is necessary to be able to revoke a pending timelock:

```solidity
rule revokePendingTimelockRevertCondition(env e) {
    bool hasGuardianRole = hasGuardianRole(e.msg.sender);

    revokePendingTimelock@withrevert(e);

    assert lastReverted <=>
        e.msg.value != 0 ||
        !hasGuardianRole;
}
```

## Timelock

MetaMorpho features a timelock mechanism that applies to every operation that could potentially increase risk for users.
The following function is verified to always return `true`.

```solidity
function isSmallerPendingTimelock() returns bool {
    uint192 pendingValue;
    pendingValue, _ = pendingTimelock();

    return assert_uint256(pendingValue) < timelock();
}
```

Notice how increasing the timelock is itself not subject to a timelock, as it does not increase the risk for the user.
Indeed, a greater timelock means that the user would have more time to react to the vault's management operations that would not align with the user risk profile.

## Interactions with other contracts

MetaMorpho interacts with Morpho Blue and with the loan token of the vault.
This section details how those calls are checked to be scoped, which ensures the safety of MetaMorpho.

### Consistent asset

For deposit and withdrawd, it is checked that markets have a the same loan token as the loan token of the vault.
We say that such market has a consistent asset.
The following function is verified to always return `true` and contributes to verifying the property above.

```solidity
function hasSupplyCapHasConsistentAsset(MetaMorphoHarness.MarketParams marketParams) returns bool {
    MetaMorphoHarness.Id id = Morpho.libId(marketParams);

    uint192 supplyCap;
    supplyCap, _, _ = config(id);

    return supplyCap > 0 => marketParams.loanToken == asset();
}
```

This checks that each market on which some supply may be deposited has a consistent asset.

### Enabled flag

It is verified that the enabled flag tracks if a given market is in the withdraw queue.
The following function gives one half of this property, and is verified to always return `true` for every index `i`.

```solidity
function isInWithdrawQueueIsEnabled(uint256 i) returns bool {
    if(i >= withdrawQueueLength()) return true;

    MetaMorphoHarness.Id id = withdrawQueue(i);
    bool enabled;
    _, enabled, _ = config(id);

    return enabled;
}
```

Thorough the code of MetaMorpho, this enabled flag is checked to be set to true, which is an efficient check that does not require to go through the whole withdraw queue.
This check also ensures that such markets have some properties, since verifying those are necessary to be added to the withdraw queue.
For example, markets added to the withdraw queue necessarily have a consistent asset.

### Last updated

### Reentrancy

## Liveness

## Other safety properties

### Range of variables

### Sanity checks

# Folder and file structure

The [`certora/specs`](specs) folder contains the following files:

- [`ConsistentState.spec`](specs/ConsistentState.spec) checks various properties specifying what is the consistent state of MetaMorpho, what are the reachable setting configurations (such as caps and fee).
- [`DistinctIdentifiers.spec`](specs/DistinctIdentifiers.spec) checks that the withdraw queue has no duplicate markets.
- [`Enabled.spec`](specs/Enabled.spec) checks properties about enabled flag of market, notably that it correctly tracks the fact that the market is in the withdraw queue.
- [`Immutability.spec`](specs/Immutability.spec) checks that MetaMorpho is immutable.
- [`LastUpdated.spec`](specs/LastUpdated.spec) checks that all Morpho Blue markets that MetaMorpho interacts with are created markets.
- [`Liveness.spec`](specs/Liveness.spec) checks some liveness properties of MetaMorpho, notably that some emergency solutions are always available.
- [`PendingValues.spec`](specs/PendingValues.spec) checks properties on the values that are still under timelock. Those properties are notably useful to prove that actual storage variables, when set to the pending value, use a consistent value.
- [`Range.spec`](specs/Range.spec) checks the bounds (if any) of storage variables.
- [`Reentrancy.spec`](specs/Reentrancy.spec) checks that MetaMorpho is reentrancy safe by making sure that there are no untrusted external calls.
- [`Reverts.spec`](specs/Reverts.spec) checks the revert conditions on entrypoints.
- [`Roles.spec`](specs/Roles.spec) checks the access control and authorization granted by the respective MetaMorpho roles. In particular it checks the hierarchy of roles.

The [`certora/confs`](confs) folder contains a configuration file for each corresponding specification file.

The [`certora/harness`](harness) folder contains helper contracts that enable the verification of MetaMorpho.
Notably, this allows handling the fact that library functions should be called from a contract to be verified independently, and it allows defining needed getters.

The [`certora/dispatch`](dispatch) folder contains different contracts similar to the ones that are expected to be called from MetaMorpho.

# Getting started

Install the `certora-cli` package with `pip install certora-cli`.
To verify specification files, pass to `certoraRun` the corresponding configuration file in the [`certora/confs`](confs) folder.
It requires having set the `CERTORAKEY` environment variable to a valid Certora key.
You can also pass additional arguments, notably to verify a specific rule.
For example, at the root of the repository:

```
certoraRun certora/confs/Range.conf --rule timelockInRange
```
