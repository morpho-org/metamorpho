# Public Allocator

These contracts were migrated from the [public-allocator](https://github.com/morpho-org/public-allocator) repository, which holds their history and PRs.

## Overview

[MetaMorpho](https://github.com/morpho-org/metamorpho) is a protocol for funds allocations and risk management on top of [Morpho Blue](https://github.com/morpho-org/morpho-blue).
The Public Allocator is a contract that MetaMorpho vault owners can enable as [allocator](https://github.com/morpho-org/metamorpho?tab=readme-ov-file#allocator) to let anybody reallocate the vault's funds to fill their liquidity needs.

The Public Allocator's function `reallocateTo` ([source](https://github.com/morpho-org/public-allocator/blob/7271fbd60881ff32a466a588f99344c6bf72629a/src/PublicAllocator.sol#L108), [interface](https://github.com/morpho-org/public-allocator/blob/7271fbd60881ff32a466a588f99344c6bf72629a/src/interfaces/IPublicAllocator.sol#L62)) reallocates some liquidity from multiple markets to one market.
It takes as input `withdrawals`, a list of pairs, which will be the markets and amounts that will be reallocated, and `supplyMarketParams`, a `MarketParams`, which is the market in which to supply the reallocated funds.
Note that the `id` of the markets in `withdrawals` must be sorted, and that `supplyMarketParams` cannot be a market of `withdrawals`.

The Public Allocator provides the possibility to the vault owner or a per vault settable admin to constrain the public reallocation:

- **Max flows**: Each market has a max inflow (`maxIn`) and max outflow (`maxOut`), that can be set by the vault owner or the Public Allocator vault admin.
  The markets from which funds are withdrawn through `reallocateTo` increase their `maxIn` and decrease their `maxOut`, and the market in which funds are deposited decrease their `maxOut` and increase their `maxIn`.
- **Fee**: If set, user must pay a fee in ETH to be able to call `reallocateTo`.
  The vault owner or the Public Allocator vault admin can set this fee, as well as taking the accumulated fees out by calling `transferFee`.

## Deployments

See the [documentation](https://docs.morpho.org/addresses#public-allocator).

## Testing

To run tests: `forge test`.
Note that running the tests this way will use this repository's compilation settings for dependencies (Morpho & MetaMorpho), potentially different from the settings used for deployment of those dependencies.

## Audits

All audits are stored in the [audits](../../../audits/)' folder.

## License

All files are licenced under `GPL-2.0-or-later`, see [`LICENSE`](../../../LICENSE).
