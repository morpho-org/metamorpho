import { BigNumberish, Signature } from "ethers";
import {
  AaveV2Bulker__factory,
  AaveV3Bulker__factory,
  BalancerBulker__factory,
  BaseBulker__factory,
  MorphoBulker__factory,
  ERC20Bulker__factory,
  MakerBulker__factory,
  StEthBulker__factory,
  UniV2Bulker__factory,
  UniV3Bulker__factory,
  WNativeBulker__factory,
} from "types";
import { PoolAddress } from "types/contracts/bulker/UniV3Bulker";
import { MarketStruct, SignatureStruct, AuthorizationStruct } from "types/contracts/interfaces/IMorpho";

export type BulkCall = string;

class BulkAction {
  private static BASE_BULKER_IFC = BaseBulker__factory.createInterface();
  private static ERC20_BULKER_IFC = ERC20Bulker__factory.createInterface();
  private static MORPHO_BULKER_IFC = MorphoBulker__factory.createInterface();
  private static WNATIVE_BULKER_IFC = WNativeBulker__factory.createInterface();
  private static ST_ETH_BULKER_IFC = StEthBulker__factory.createInterface();
  private static AAVE_V2_BULKER_IFC = AaveV2Bulker__factory.createInterface();
  private static AAVE_V3_BULKER_IFC = AaveV3Bulker__factory.createInterface();
  private static MAKER_BULKER_IFC = MakerBulker__factory.createInterface();
  private static BALANCER_BULKER_IFC = BalancerBulker__factory.createInterface();
  private static UNI_V2_BULKER_IFC = UniV2Bulker__factory.createInterface();
  private static UNI_V3_BULKER_IFC = UniV3Bulker__factory.createInterface();

  static callBulker(bulker: string, calls: BulkCall[]): BulkCall {
    return BulkAction.BASE_BULKER_IFC.encodeFunctionData("callBulker", [bulker, calls]);
  }

  static transfer(asset: string, recipient: string, amount: BigNumberish): BulkCall {
    return BulkAction.ERC20_BULKER_IFC.encodeFunctionData("transfer", [asset, recipient, amount]);
  }

  static approve2(asset: string, amount: BigNumberish, deadline: BigNumberish, signature: Signature): BulkCall {
    return BulkAction.ERC20_BULKER_IFC.encodeFunctionData("approve2", [
      asset,
      amount,
      deadline,
      { v: signature.v, r: signature.r, s: signature.s },
    ]);
  }

  static transferFrom2(asset: string, amount: BigNumberish): BulkCall {
    return BulkAction.ERC20_BULKER_IFC.encodeFunctionData("transferFrom2", [asset, amount]);
  }

  static morphoSetAuthorization(authorization: AuthorizationStruct, signature: SignatureStruct): BulkCall {
    return BulkAction.MORPHO_BULKER_IFC.encodeFunctionData("morphoSetAuthorization", [authorization, signature]);
  }

  static morphoSupply(
    market: MarketStruct,
    amount: BigNumberish,
    shares: BigNumberish,
    onBehalf: string,
    callbackCalls: BulkCall[],
  ): BulkCall {
    return BulkAction.MORPHO_BULKER_IFC.encodeFunctionData("morphoSupply", [
      market,
      amount,
      shares,
      onBehalf,
      BulkAction.MORPHO_BULKER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoSupplyCollateral(
    market: MarketStruct,
    amount: BigNumberish,
    onBehalf: string,
    callbackCalls: BulkCall[],
  ): BulkCall {
    return BulkAction.MORPHO_BULKER_IFC.encodeFunctionData("morphoSupplyCollateral", [
      market,
      amount,
      onBehalf,
      BulkAction.MORPHO_BULKER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoBorrow(market: MarketStruct, amount: BigNumberish, receiver: string): BulkCall {
    return BulkAction.MORPHO_BULKER_IFC.encodeFunctionData("morphoBorrow", [market, amount, shares, receiver]);
  }

  static morphoRepay(
    market: MarketStruct,
    amount: BigNumberish,
    shares: BigNumberish,
    onBehalf: string,
    callbackCalls: BulkCall[],
  ): BulkCall {
    return BulkAction.MORPHO_BULKER_IFC.encodeFunctionData("morphoRepay", [
      market,
      amount,
      shares,
      onBehalf,
      BulkAction.MORPHO_BULKER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoWithdraw(market: MarketStruct, amount: BigNumberish, shares: BigNumberish, receiver: string): BulkCall {
    return BulkAction.MORPHO_BULKER_IFC.encodeFunctionData("morphoWithdraw", [market, amount, shares, receiver]);
  }

  static morphoWithdrawCollateral(market: MarketStruct, amount: BigNumberish, receiver: string): BulkCall {
    return BulkAction.MORPHO_BULKER_IFC.encodeFunctionData("morphoWithdrawCollateral", [market, amount, receiver]);
  }

  static morphoLiquidate(
    market: MarketStruct,
    borrower: string,
    amount: BigNumberish,
    callbackCalls: BulkCall[],
  ): BulkCall {
    return BulkAction.MORPHO_BULKER_IFC.encodeFunctionData("morphoLiquidate", [
      market,
      borrower,
      amount,
      BulkAction.MORPHO_BULKER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static morphoFlashLoan(asset: string, amount: BigNumberish, callbackCalls: BulkCall[]): BulkCall {
    return BulkAction.MORPHO_BULKER_IFC.encodeFunctionData("morphoFlashLoan", [
      asset,
      amount,
      BulkAction.MORPHO_BULKER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static wrapNative(amount: BigNumberish, receiver: string): BulkCall {
    return BulkAction.WNATIVE_BULKER_IFC.encodeFunctionData("wrapNative", [amount, receiver]);
  }

  static unwrapNative(amount: BigNumberish, receiver: string): BulkCall {
    return BulkAction.WNATIVE_BULKER_IFC.encodeFunctionData("unwrapNative", [amount, receiver]);
  }

  static wrapStEth(amount: BigNumberish, receiver: string): BulkCall {
    return BulkAction.ST_ETH_BULKER_IFC.encodeFunctionData("wrapStEth", [amount, receiver]);
  }

  static unwrapStEth(amount: BigNumberish, receiver: string): BulkCall {
    return BulkAction.ST_ETH_BULKER_IFC.encodeFunctionData("unwrapStEth", [amount, receiver]);
  }

  static aaveV2FlashLoan(assets: string[], amounts: BigNumberish[], callbackCalls: BulkCall[]): BulkCall {
    return BulkAction.AAVE_V2_BULKER_IFC.encodeFunctionData("aaveV2FlashLoan", [
      assets,
      amounts,
      BulkAction.MORPHO_BULKER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static aaveV3FlashLoan(assets: string[], amounts: BigNumberish[], callbackCalls: BulkCall[]): BulkCall {
    return BulkAction.AAVE_V3_BULKER_IFC.encodeFunctionData("aaveV3FlashLoan", [
      assets,
      amounts,
      BulkAction.MORPHO_BULKER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static makerFlashLoan(asset: string, amount: BigNumberish, callbackCalls: BulkCall[]): BulkCall {
    return BulkAction.MAKER_BULKER_IFC.encodeFunctionData("makerFlashLoan", [
      asset,
      amount,
      BulkAction.MORPHO_BULKER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static balancerFlashLoan(assets: string[], amounts: BigNumberish[], callbackCalls: BulkCall[]): BulkCall {
    return BulkAction.BALANCER_BULKER_IFC.encodeFunctionData("balancerFlashLoan", [
      assets,
      amounts,
      BulkAction.MORPHO_BULKER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static uniV2FlashSwap(
    token0: string,
    token1: string,
    amount0: BigNumberish,
    amount1: BigNumberish,
    callbackCalls: BulkCall[],
  ): BulkCall {
    return BulkAction.UNI_V2_BULKER_IFC.encodeFunctionData("uniV2FlashSwap", [
      token0,
      token1,
      amount0,
      amount1,
      BulkAction.MORPHO_BULKER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }

  static uniV3FlashSwap(
    poolKey: PoolAddress.PoolKeyStruct,
    amount0: BigNumberish,
    amount1: BigNumberish,
    callbackCalls: BulkCall[],
  ): BulkCall {
    return BulkAction.UNI_V3_BULKER_IFC.encodeFunctionData("uniV3FlashSwap", [
      poolKey,
      amount0,
      amount1,
      BulkAction.MORPHO_BULKER_IFC._abiCoder.encode(["bytes[]"], [callbackCalls]),
    ]);
  }
}

export default BulkAction;
