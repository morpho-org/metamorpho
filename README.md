# Morpho Blue MetaMorpho

[Morpho Blue](https://github.com/morpho-org/morpho-blue) is a trustless lending primitive that offers unparalleled efficiency and flexibility.

MetaMorpho is a protocol for noncustodial risk management built on top of Morpho Blue. It enables anyone to create a vault depositing liquidity into multiple Morpho Blue markets. It offers a seamless experience similar to Aave and Compound.

Users of MetaMorpho are liquidity providers that want to earn from borrowing interest whithout having to actively manage the risk of their position. The active management of the deposited assets is the responsibility of a set of different roles (owner, risk manager and allocators). These roles are primarily responsible for enabling and disabling markets on Morpho Blue and managing the allocation of users’ funds.

## Getting Started

Install dependencies: `yarn`

Run forge tests: `yarn test:forge`

Run hardhat tests: `yarn test:hardhat`

You will find other useful commands in the [`package.json`](./package.json) file.

## License

Morpho Blue Oracles is licensed under `GPL-2.0-or-later`, see [`LICENSE`](./LICENSE).
