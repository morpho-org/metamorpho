# Morpho Blue MetaMorpho

[Morpho Blue](https://github.com/morpho-org/morpho-blue) is a trustless lending primitive that offers unparalleled efficiency and flexibility.

MetaMorpho is a protocol for noncustodial risk management built on top of Morpho Blue.
It enables anyone to create a vault depositing liquidity into multiple Morpho Blue markets.
It offers a seamless experience similar to Aave and Compound.

Users of MetaMorpho are liquidity providers that want to earn from borrowing interest whithout having to actively manage the risk of their position.
The active management of the deposited assets is the responsibility of a set of different roles (owner, curator and allocators).
These roles are primarily responsible for enabling and disabling markets on Morpho Blue and managing the allocation of users’ funds.

## Specifications

### MetaMorpho

MetaMorpho vaults are ERC-4626 compliant vault with the permit feature (ERC-2612). One MetaMorpho vault is related to one loan asset on Morpho Blue.

Users can supply or withdraw assets at any time, depending on the available liquidity on Morpho Blue.
A maximum of 30 markets can be enabled on a given MetaMorpho vault.

There are 4 different roles for a MetaMorpho vault (owner, curator, guardian & allocators).
All actions that are against users' interests (e.g. enabling a market with a high exposure, increasing the fee) are subject to a timelock of minimum 12 hours.
During this timelock, users who disagree with the policy change can withdraw their funds from the vault or the guardian (if it is set) can revoke the action. After the timelock, the action can be executed by anyone until 3 days have passed.

In case the vault receives rewards on Morpho Blue markets, the rewards can be redistributed by setting a rewards recipient. This rewards recipient can be [Universal Rewards Distributor (URD)](https://github.com/morpho-org/universal-rewards-distributor).

### Roles

The owner can:
- Do whatever the curator and allocators can do.
- Transfer or renounce the ownership.
- Set the curator.
- Set allocators.
- Set the rewards recipient.
- [Timelocked] Set the timelock.
- [Timelocked] Set the performance fee (capped to 50%).
- [Timelocked] Set the guardian.
- Set the fee recipient.

The curator can:
- Do whatever the allocators can do.
- [Timelocked] Enable or disable a market by setting a cap to a specific market.
    - The cap must be set to 0 to disable the market.
	- Disabling a market can then only be done if the vault has no liquidity supplied on the market.

The allocators can:
- Set the `supplyQueue` and `withdrawQueue`, ie decides on the order of the markets to supply/withdraw from.
    - Upon a deposit, the vault will supply up to the cap of each Morpho Blue market in the supply queue in the order set. The remaining funds are left as idle supply on the vault (uncapped).
	- Upon a withdrawal, the vault will first withdraw from the idle supply, then withdraw up to the liquidity of each Morpho Blue market in the withdrawal queue in the order set.
	- The `supplyQueue` can only contain enabled markets.
	- The `withdrawQueue` MUST contain all enabled markets on which the vault has still liquidity (enabled market are markets with non-zero cap or with non-zero vault's supply).
- Reallocate funds among the enabled market at any moment.

The guardian can:
- Revoke any timelocked action.

Anyone can:
- Trigger the ERC-4626 entry points.
- Transfer rewards to the rewards recipient.

### MetaMorpho Factory

The MetaMorpho factory is permissionless factory contract that allows anyone to create a new MetaMorpho vault.

## Getting Started

Install dependencies: `yarn`

Run forge tests: `yarn test:forge`

Run hardhat tests: `yarn test:hardhat`

You will find other useful commands in the [`package.json`](./package.json) file.

## License

Morpho Blue Oracles is licensed under `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).
