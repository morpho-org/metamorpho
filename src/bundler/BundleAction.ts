import { BigNumberish, Signature } from "ethers";
import {
  AaveV2Bundler__factory,
  AaveV3Bundler__factory,
  BalancerBundler__factory,
  BaseBundler__factory,
  MorphoBundler__factory,
  ERC20Bundler__factory,
  MakerBundler__factory,
  StEthBundler__factory,
  UniV2Bundler__factory,
  UniV3Bundler__factory,
  WNativeBundler__factory,
} from "types";
import { PoolAddress } from "types/contracts/bundler/UniV3Bundler";
import { MarketStruct, SignatureStruct, AuthorizationStruct } from "types/contracts/interfaces/IMorpho";

export type BundleCall = string;

class BundleAction {
  private static ERC20_BUNDLER_IFC = ERC20Bundler__factory.createInterface();
  private static MORPHO_BUNDLER_IFC = MorphoBundler__factory.createInterface();
  private static WNATIVE_BUNDLER_IFC = WNativeBundler__factory.createInterface();
  private static ST_ETH_BUNDLER_IFC = StEthBundler__factory.createInterface();
  private static AAVE_V2_BUNDLER_IFC = AaveV2Bundler__factory.createInterface();
  private static AAVE_V3_BUNDLER_IFC = AaveV3Bundler__factory.createInterface();
  private static MAKER_BUNDLER_IFC = MakerBundler__factory.createInterface();
  private static BALANCER_BUNDLER_IFC = BalancerBundler__factory.createInterface();
  private static UNI_V2_BUNDLER_IFC = UniV2Bundler__factory.createInterface();
  private static UNI_V3_BUNDLER_IFC = UniV3Bundler__factory.createInterface();

  static transfer(asset: string, recipient: string, amount: BigNumberish): BundleCall {
    return BundleAction.ERC20_BUNDLER_IFC.encodeFunctionData("transfer", [asset, recipient, amount]);
  }

  static approve2(asset: string, amount: BigNumberish, deadline: BigNumberish, signature: Signature): BundleCall {
    return BundleAction.ERC20_BUNDLER_IFC.encodeFunctionData("approve2", [
      asset,
      amount,
      deadline,
      { v: signature.v, r: signature.r, s: signature.s },
    ]);
  }

  static transferFrom2(asset: string, amount: BigNumberish): BundleCall {
    return BundleAction.ERC20_BUNDLER_IFC.encodeFunctionData("transferFrom2", [asset, amount]);
  }

  static morphoSetAuthorizationWithSig(authorization: AuthorizationStruct, signature: SignatureStruct): BundleCall {
    return BundleAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoSetAuthorizationWithSig", [
      authorization,
      signature,
    ]);
  }

  static morphoSupply(
    market: MarketStruct,
    amount: BigNumberish,
    shares: BigNumberish,
    onBehalf: string,
    callbackCalls: BundleCall[],
  ): BundleCall {
    return BundleAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoSupply", [
      market,
      amount,
      shares,
      onBehalf,
      BundleAction.MORPHO_BUNDLER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoSupplyCollateral(
    market: MarketStruct,
    amount: BigNumberish,
    onBehalf: string,
    callbackCalls: BundleCall[],
  ): BundleCall {
    return BundleAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoSupplyCollateral", [
      market,
      amount,
      onBehalf,
      BundleAction.MORPHO_BUNDLER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoBorrow(market: MarketStruct, amount: BigNumberish, shares: BigNumberish, receiver: string): BundleCall {
    return BundleAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoBorrow", [market, amount, shares, receiver]);
  }

  static morphoRepay(
    market: MarketStruct,
    amount: BigNumberish,
    shares: BigNumberish,
    onBehalf: string,
    callbackCalls: BundleCall[],
  ): BundleCall {
    return BundleAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoRepay", [
      market,
      amount,
      shares,
      onBehalf,
      BundleAction.MORPHO_BUNDLER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoWithdraw(
    market: MarketStruct,
    amount: BigNumberish,
    shares: BigNumberish,
    receiver: string,
  ): BundleCall {
    return BundleAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoWithdraw", [market, amount, shares, receiver]);
  }

  static morphoWithdrawCollateral(market: MarketStruct, amount: BigNumberish, receiver: string): BundleCall {
    return BundleAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoWithdrawCollateral", [market, amount, receiver]);
  }

  static morphoLiquidate(
    market: MarketStruct,
    borrower: string,
    seizedAssets: BigNumberish,
    repaidShares: BigNumberish,
    callbackCalls: BundleCall[],
  ): BundleCall {
    return BundleAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoLiquidate", [
      market,
      borrower,
      seizedAssets,
      repaidShares,
      BundleAction.MORPHO_BUNDLER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoFlashLoan(asset: string, amount: BigNumberish, callbackCalls: BundleCall[]): BundleCall {
    return BundleAction.MORPHO_BUNDLER_IFC.encodeFunctionData("morphoFlashLoan", [
      asset,
      amount,
      BundleAction.MORPHO_BUNDLER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static wrapNative(amount: BigNumberish, receiver: string): BundleCall {
    return BundleAction.WNATIVE_BUNDLER_IFC.encodeFunctionData("wrapNative", [amount, receiver]);
  }

  static unwrapNative(amount: BigNumberish, receiver: string): BundleCall {
    return BundleAction.WNATIVE_BUNDLER_IFC.encodeFunctionData("unwrapNative", [amount, receiver]);
  }

  static wrapStEth(amount: BigNumberish, receiver: string): BundleCall {
    return BundleAction.ST_ETH_BUNDLER_IFC.encodeFunctionData("wrapStEth", [amount, receiver]);
  }

  static unwrapStEth(amount: BigNumberish, receiver: string): BundleCall {
    return BundleAction.ST_ETH_BUNDLER_IFC.encodeFunctionData("unwrapStEth", [amount, receiver]);
  }

  static aaveV2FlashLoan(assets: string[], amounts: BigNumberish[], callbackCalls: BundleCall[]): BundleCall {
    return BundleAction.AAVE_V2_BUNDLER_IFC.encodeFunctionData("aaveV2FlashLoan", [
      assets,
      amounts,
      BundleAction.MORPHO_BUNDLER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static aaveV3FlashLoan(assets: string[], amounts: BigNumberish[], callbackCalls: BundleCall[]): BundleCall {
    return BundleAction.AAVE_V3_BUNDLER_IFC.encodeFunctionData("aaveV3FlashLoan", [
      assets,
      amounts,
      BundleAction.MORPHO_BUNDLER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static makerFlashLoan(asset: string, amount: BigNumberish, callbackCalls: BundleCall[]): BundleCall {
    return BundleAction.MAKER_BUNDLER_IFC.encodeFunctionData("makerFlashLoan", [
      asset,
      amount,
      BundleAction.MORPHO_BUNDLER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static balancerFlashLoan(assets: string[], amounts: BigNumberish[], callbackCalls: BundleCall[]): BundleCall {
    return BundleAction.BALANCER_BUNDLER_IFC.encodeFunctionData("balancerFlashLoan", [
      assets,
      amounts,
      BundleAction.MORPHO_BUNDLER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static uniV2FlashSwap(
    token0: string,
    token1: string,
    amount0: BigNumberish,
    amount1: BigNumberish,
    callbackCalls: BundleCall[],
  ): BundleCall {
    return BundleAction.UNI_V2_BUNDLER_IFC.encodeFunctionData("uniV2FlashSwap", [
      token0,
      token1,
      amount0,
      amount1,
      BundleAction.MORPHO_BUNDLER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static uniV3FlashSwap(
    poolKey: PoolAddress.PoolKeyStruct,
    amount0: BigNumberish,
    amount1: BigNumberish,
    callbackCalls: BundleCall[],
  ): BundleCall {
    return BundleAction.UNI_V3_BUNDLER_IFC.encodeFunctionData("uniV3FlashSwap", [
      poolKey,
      amount0,
      amount1,
      BundleAction.MORPHO_BUNDLER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }
}

export default BundleAction;
