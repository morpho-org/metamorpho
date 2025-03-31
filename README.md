# MetaMorpho

## Overview

MetaMorpho is a protocol for noncustodial risk management on top of [Morpho Blue](https://github.com/morpho-org/morpho-blue).
It enables anyone to create a vault depositing liquidity into multiple Morpho Blue markets.
It offers a seamless experience similar to Aave and Compound.

Users of MetaMorpho are liquidity providers who want to earn from borrowing interest without having to actively manage the risk of their position.
The active management of the deposited assets is the responsibility of a set of different roles (owner, curator and allocators).
These roles are primarily responsible for enabling and disabling markets on Morpho Blue and managing the allocation of users’ funds.

[`MetaMorpho`](./src/MetaMorpho.sol) vaults are [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) vaults, with ([ERC-2612](https://eips.ethereum.org/EIPS/eip-2612)) permit.
One MetaMorpho vault is related to one loan asset on Morpho Blue.
The [`MetaMorphoFactory`](./src/MetaMorphoFactory.sol) is deploying immutable onchain instances of MetaMorpho vaults.

Users can supply or withdraw assets at any time, depending on the available liquidity on Morpho Blue.
A maximum of 30 markets can be enabled on a given MetaMorpho vault.
Each market has a supply cap that guarantees lenders a maximum absolute exposure to the specific market. By default, the supply cap of a market is set to 0.

There are 4 different roles for a MetaMorpho vault: owner, curator, guardian & allocator.

The vault owner can set a performance fee, cutting up to 50% of the generated interest.
The `feeRecipient` can then withdraw the accumulated fee at any time.

The vault may be entitled to some rewards emitted on Morpho Blue markets the vault has supplied to.
Those rewards can be transferred to the `skimRecipient`.
The vault's owner has the choice to distribute back these rewards to vault depositors however they want.
For more information about this use case, see the [Rewards](#rewards) section.

All actions that may be against users' interests (e.g. enabling a market with a high exposure) are subject to a timelock of minimum 24 hours.
The `owner`, or the `guardian` if set, can revoke the action during the timelock.
After the timelock, the action can be executed by anyone.

### Roles

#### Owner

Only one address can have this role.

It can:

- Do what the curator can do.
- Do what the guardian can do.
- Transfer or renounce the ownership.
- Set the curator.
- Set allocators.
- Set the rewards recipient.
- Increase the timelock.
- [Timelocked] Decrease the timelock.
- [Timelocked if already set] Set the guardian.
- Set the performance fee (capped at 50%).
- Set the fee recipient.

#### Curator

Only one address can have this role.

It can:

- Do what allocators can do.
- Decrease the supply cap of any market.
  - To softly remove a market after the curator has set the supply cap to 0, it is expected from the allocator role to reallocate the supplied liquidity to another enabled market and then to update the withdraw queue.
- [Timelocked] Increase the supply cap of any market.
- [Timelocked] Submit the forced removal of a market.
  - This action is typically designed to force the removal of a market that keeps reverting thus locking the vault.
  - After the timelock has elapsed, the allocator role is free to remove the market from the withdraw queue. The funds supplied to this market will be lost.
  - If the market ever functions again, the allocator role can withdraw the funds that were previously lost.
- Revoke the pending cap of any market.
- Revoke the pending removal of any market.

#### Allocator

Multiple addresses can have this role.

It can:

- Set the `supplyQueue` and `withdrawQueue`, i.e. decide on the order of the markets to supply/withdraw from.
  - Upon a deposit, the vault will supply up to the cap of each Morpho Blue market in the `supplyQueue` in the order set.
  - Upon a withdrawal, the vault will withdraw up to the liquidity of each Morpho Blue market in the `withdrawQueue` in the order set.
  - The `supplyQueue` only contains markets which cap has previously been non-zero.
  - The `withdrawQueue` contains all markets that have a non-zero cap or a non-zero vault allocation.
- Instantaneously reallocate funds by supplying on markets of the `withdrawQueue` and withdrawing from markets that have the same loan asset as the vault's asset.

> **Warning**
> If `supplyQueue` is empty, depositing to the vault is disabled.

#### Guardian

Only one address can have this role.

It can:

- Revoke the pending timelock.
- Revoke the pending guardian (which means it can revoke any attempt to change the guardian).
- Revoke the pending cap of any market.
- Revoke the pending removal of any market.

### Idle Supply

In some cases, the vault's curator or allocators may want to keep some funds "idle", to guarantee lenders that some liquidity can be withdrawn from the vault (beyond the liquidity of each of the vault's markets).

To achieve this, they can deposit in markets with `address(0)` as the oracle or the collateral, ensuring that these funds can't be borrowed.
They are thus guaranteed to be liquid; though they won't generate interest.
It is advised to use these canonical configurations for "idle" markets:

- `loanToken`: The vault's asset to be able to supply/withdraw funds.
- `collateralToken`: `address(0)` (not necessary since no funds will be borrowed on this market)
- `irm`: `address(0)` (Morpho Blue will skip the call to the IRM in this case, thus reducing the gas cost)
- `oracle`: `address(0)` (not necessary since no funds will be borrowed on this market)
- `lltv`: `0` (not necessary since no funds will be borrowed on this market)

Note that to allocate funds to this idle market, it is first required to enable its cap on MetaMorpho.
Enabling an infinite cap (`type(uint184).max`) will always allow users to deposit on the vault.

### Rewards

To redistribute rewards to vault depositors, it is advised to use the [Universal Rewards Distributor (URD)](https://github.com/morpho-org/universal-rewards-distributor).

Below is a typical example of how this use case would take place:

- If not already done:

  - Create a rewards distributor using the [UrdFactory](https://github.com/morpho-org/universal-rewards-distributor/blob/main/src/UrdFactory.sol) (can be done by anyone).
  - Set the vault’s rewards recipient address to the created URD using `setSkimRecipient`.

- Claim tokens from the Morpho Blue distribution to the vault.

  NB: Anyone can claim tokens on behalf of the vault and automatically transfer them to the vault.
  Thus, this step might be already performed by some third-party.

- Transfer rewards from the vault to the rewards distributor using the `skim` function.

  NB: Anyone can transfer rewards from the vault to the rewards distributor unless it is unset.
  Thus, this step might be already performed by some third-party.
  Note: the amount of rewards transferred corresponds to the vault's balance of reward asset.

- Compute the new root for the vault’s rewards distributor, submit it, wait for the timelock (if any), accept the root, and let vault depositors claim their rewards according to the vault manager’s rewards re-distribution strategy.

## Emergency

### An enabled market is now considered unsafe

If an enabled market is considered unsafe (e.g., risk too high), the curator/owner may want to disable this market in the following way:

- 1. Revoke the pending cap of the market with the `revokePendingCap` function (this can also be done by the guardian).
- 2. Set the cap of the market to 0 with the `submitCap` function.
     To ensure that submit cap does not revert because of a pending cap, it is recommended to batch the two previous transactions, for example using the multicall function of MetaMorpho.
- 3. Withdraw all the supply of this market with the `reallocate` function.
     If there is not enough liquidity on the market, remove the maximum available liquidity with the `reallocate` function, then put the market at the beginning of the withdraw queue (with the `updateWithdrawQueue` function).
- 4. Once all the supply has been removed from the market, the market can be removed from the withdraw queue with the `updateWithdrawQueue` function.

### An enabled market reverts

If an enabled market starts reverting, many of the vault functions would revert as well (because of the call to `totalAssets`). To turn the vault back to an operating state, the market must be forced removed by the owner/curator, who should follow these steps:

- 1. Revoke the pending cap of the market with the `revokePendingCap` function (this can also be done by the guardian).
- 2. Set the cap of the market to 0 with the `submitCap` function.
     To ensure that submit cap does not revert because of a pending cap, it is recommended to batch the two previous transactions, for example using the multicall function of MetaMorpho.
- 3. Submit a removal of the market with the `submitMarketRemoval` function.
- 4. Wait for the timelock to elapse
- 5. Once the timelock has elapsed, the market can be removed from the withdraw queue with the `updateWithdrawQueue` function.

Warning : Funds supplied in forced removed markets will be lost, this is why only markets expected to always revert should be disabled this way (because funds supplied in such markets can be considered lost anyway).

### Curator takeover

If the curator starts to submit positive caps for unsafe markets that are not in line with the vault risk strategy, the owner of the vault can:

- 1. Set a new curator with the `setCurator` function.
- 2. Revoke the pending caps submitted by the curator (this can also be done by the guardian or the new curator).
- 3. If the curator had the time to accept a cap (because `timelock` has elapsed before the guardian or the owner had time to act), the owner (or the new curator) must disable the unsafe market (see [above](#an-enabled-market-is-now-considered-unsafe)).

### Allocator takeover

If one of the allocators starts setting the withdraw queue and/or supply queue that are not in line with the vault risk strategy, or incoherently reallocating the funds, the owner of the vault should:

- 1. Deprive the faulty allocator from his privileges with the `setIsAllocator` function.
- 2. Reallocate the funds in a way consistent with the vault risk strategy with the `reallocate` function (this can also be done by the curator or the other allocators).
- 3. Set a new withdraw queue that is in line with the vault risk strategy with the `updateWithdrawQueue` function (this can also be done by the curator or the other allocators).
- 4. Set a new supply queue that is in line with the vault risk strategy with the `setSupplyQueue` function (this can also be done by the curator or the other allocators).

## Development

Install dependencies: `yarn`

Run forge tests: `yarn test:forge`

Run hardhat tests: `yarn test:hardhat`

You will find other useful commands in the [`package.json`](./package.json) file.

## Audits

All audits are stored in the [audits](./audits/)' folder.

## License

MetaMorpho is licensed under `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).
