import { BigNumberish, Signature } from "ethers";
import {
  ERC20Bundler__factory,
  ERC4626Bundler__factory,
  MorphoBundler__factory,
  StEthBundler__factory,
  WNativeBundler__factory,
} from "types";
import { AuthorizationStruct, MarketParamsStruct, SignatureStruct } from "types/contracts/bundlers/MorphoBundler";

export type BundlerCall = string;

class BundlerAction {
  private static ERC20_BUNDLER_IFC = ERC20Bundler__factory.createInterface();
  private static ERC4626_BUNDLER_IFC = ERC4626Bundler__factory.createInterface();
  private static MORPHO_BUNDLER_IFC = MorphoBundler__factory.createInterface();
  private static WNATIVE_BUNDLER_IFC = WNativeBundler__factory.createInterface();
  private static ST_ETH_BUNDLER_IFC = StEthBundler__factory.createInterface();

  /* ERC20 */

  static transfer(asset: string, recipient: string, amount: BigNumberish): BundlerCall {
    return BundlerAction.ERC20_BUNDLER_IFC.encodeFunctionData("transfer", [asset, recipient, amount]);
  }

  static approve2(asset: string, amount: BigNumberish, deadline: BigNumberish, signature: Signature): BundlerCall {
    return BundlerAction.ERC20_BUNDLER_IFC.encodeFunctionData("approve2", [
      asset,
      amount,
      deadline,
      { v: signature.v, r: signature.r, s: signature.s },
    ]);
  }

  static transferFrom2(asset: string, amount: BigNumberish): BundlerCall {
    return BundlerAction.ERC20_BUNDLER_IFC.encodeFunctionData("transferFrom2", [asset, amount]);
  }

  /* ERC4626 */

  static mint(erc4626: string, amount: BigNumberish, receiver: string): BundlerCall {
    return BundlerAction.ERC4626_BUNDLER_IFC.encodeFunctionData("mint", [erc4626, amount, receiver]);
  }

  static deposit(erc4626: string, amount: BigNumberish, receiver: string): BundlerCall {
    return BundlerAction.ERC4626_BUNDLER_IFC.encodeFunctionData("deposit", [erc4626, amount, receiver]);
  }

  static withdraw(erc4626: string, amount: BigNumberish, receiver: string): BundlerCall {
    return BundlerAction.ERC4626_BUNDLER_IFC.encodeFunctionData("withdraw", [erc4626, amount, receiver]);
  }

  static redeem(erc4626: string, amount: BigNumberish, receiver: string): BundlerCall {
    return BundlerAction.ERC4626_BUNDLER_IFC.encodeFunctionData("redeem", [erc4626, amount, receiver]);
  }

  /* Morpho */

  static morphoSetAuthorizationWithSig(authorization: AuthorizationStruct, signature: SignatureStruct): BundlerCall {
    return BundlerAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoSetAuthorizationWithSig", [
      authorization,
      signature,
    ]);
  }

  static morphoSupply(
    market: MarketParamsStruct,
    amount: BigNumberish,
    shares: BigNumberish,
    onBehalf: string,
    callbackCalls: BundlerCall[],
  ): BundlerCall {
    return BundlerAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoSupply", [
      market,
      amount,
      shares,
      onBehalf,
      BundlerAction.MORPHO_BUNDLER_IFC.getAbiCoder().encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoSupplyCollateral(
    market: MarketParamsStruct,
    amount: BigNumberish,
    onBehalf: string,
    callbackCalls: BundlerCall[],
  ): BundlerCall {
    return BundlerAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoSupplyCollateral", [
      market,
      amount,
      onBehalf,
      BundlerAction.MORPHO_BUNDLER_IFC.getAbiCoder().encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoBorrow(
    market: MarketParamsStruct,
    amount: BigNumberish,
    shares: BigNumberish,
    receiver: string,
  ): BundlerCall {
    return BundlerAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoBorrow", [market, amount, shares, receiver]);
  }

  static morphoRepay(
    market: MarketParamsStruct,
    amount: BigNumberish,
    shares: BigNumberish,
    onBehalf: string,
    callbackCalls: BundlerCall[],
  ): BundlerCall {
    return BundlerAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoRepay", [
      market,
      amount,
      shares,
      onBehalf,
      BundlerAction.MORPHO_BUNDLER_IFC.getAbiCoder().encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoWithdraw(
    market: MarketParamsStruct,
    amount: BigNumberish,
    shares: BigNumberish,
    receiver: string,
  ): BundlerCall {
    return BundlerAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoWithdraw", [market, amount, shares, receiver]);
  }

  static morphoWithdrawCollateral(market: MarketParamsStruct, amount: BigNumberish, receiver: string): BundlerCall {
    return BundlerAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoWithdrawCollateral", [market, amount, receiver]);
  }

  static morphoLiquidate(
    market: MarketParamsStruct,
    borrower: string,
    seizedAssets: BigNumberish,
    repaidShares: BigNumberish,
    callbackCalls: BundlerCall[],
  ): BundlerCall {
    return BundlerAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoLiquidate", [
      market,
      borrower,
      seizedAssets,
      repaidShares,
      BundlerAction.MORPHO_BUNDLER_IFC.getAbiCoder().encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoFlashLoan(asset: string, amount: BigNumberish, callbackCalls: BundlerCall[]): BundlerCall {
    return BundlerAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoFlashLoan", [
      asset,
      amount,
      BundlerAction.MORPHO_BUNDLER_IFC.getAbiCoder().encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  /* Wrapped Native */

  static wrapNative(amount: BigNumberish, receiver: string): BundlerCall {
    return BundlerAction.WNATIVE_BUNDLER_IFC.encodeFunctionData("wrapNative", [amount, receiver]);
  }

  static unwrapNative(amount: BigNumberish, receiver: string): BundlerCall {
    return BundlerAction.WNATIVE_BUNDLER_IFC.encodeFunctionData("unwrapNative", [amount, receiver]);
  }

  /* Wrapped stETH */

  static wrapStEth(amount: BigNumberish, receiver: string): BundlerCall {
    return BundlerAction.ST_ETH_BUNDLER_IFC.encodeFunctionData("wrapStEth", [amount, receiver]);
  }

  static unwrapStEth(amount: BigNumberish, receiver: string): BundlerCall {
    return BundlerAction.ST_ETH_BUNDLER_IFC.encodeFunctionData("unwrapStEth", [amount, receiver]);
  }
}

export default BundlerAction;
