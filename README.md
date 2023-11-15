# MetaMorpho

## Overview

MetaMorpho is a protocol for noncustodial risk management on top of [Morpho Blue](https://github.com/morpho-org/morpho-blue).
It enables anyone to create a vault depositing liquidity into multiple Morpho Blue markets.
It offers a seamless experience similar to Aave and Compound.

Users of MetaMorpho are liquidity providers that want to earn from borrowing interest without having to actively manage the risk of their position.
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

All actions that may be against users' interests (e.g. enabling a market with a high exposure, increasing the fee) are subject to a timelock of minimum 12 hours.
If set, the `guardian` can revoke the action during the timelock except for the fee increase.
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
- [Timelocked with no possible veto] Set the performance fee (capped to 50%).
- [Timelocked] Set the guardian.
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

#### Allocator

Multiple addresses can have this role.

It can:

- Set the `supplyQueue` and `withdrawQueue`, i.e. decide on the order of the markets to supply/withdraw from.
  - Upon a deposit, the vault will supply up to the cap of each Morpho Blue market in the `supplyQueue` in the order set.
  - Upon a withdrawal, the vault will first withdraw from the idle supply and then withdraw up to the liquidity of each Morpho Blue market in the `withdrawalQueue` in the order set.
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

### Idle Supply

In some cases, the vault's curator or allocators may want to keep some funds "idle", to guarantee lenders that some liquidity can be withdrawn from the vault (beyond the liquidity of each of the vault's markets).

To achieve this, it is advised to allocate "idle" funds to any market on Morpho Blue having:

- The vault's asset as loan token.
- No collateral token (`address(0)`).
- An arbitrary IRM.
- An arbitrary oracle (`address(0)`).
- An arbitrary LLTV.

Thus, these funds cannot be borrowed on Morpho Blue and are guaranteed to be liquid; though it won't generate interest.

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

## Getting Started

Install dependencies: `yarn`

Run forge tests: `yarn test:forge`

Run hardhat tests: `yarn test:hardhat`

You will find other useful commands in the [`package.json`](./package.json) file.

## Audits

All audits are stored in the [audits](./audits/)' folder.

## License

MetaMorpho is licensed under `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).
