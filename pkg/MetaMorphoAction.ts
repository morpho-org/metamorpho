import { BigNumberish } from "ethers";
import { MetaMorpho__factory } from "types";
import { MarketAllocationStruct, MarketParamsStruct } from "types/src/MetaMorpho";

export type MetaMorphoCall = string;

export class MetaMorphoAction {
  private static METAMORPHO_IFC = MetaMorpho__factory.createInterface();

  /* CONFIGURATION */

  static setCurator(newCurator: string): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("setCurator", [newCurator]);
  }

  static setIsAllocator(newAllocator: string, newIsAllocator: boolean): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("setIsAllocator", [newAllocator, newIsAllocator]);
  }

  static setFeeRecipient(newFeeRecipient: string): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("setFeeRecipient", [newFeeRecipient]);
  }

  static setSkimRecipient(newSkimRecipient: string): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("setSkimRecipient", [newSkimRecipient]);
  }

  static setFee(fee: BigNumberish): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("setFee", [fee]);
  }

  /* TIMELOCK */

  static submitTimelock(newTimelock: BigNumberish): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("submitTimelock", [newTimelock]);
  }

  static acceptTimelock(): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("acceptTimelock");
  }

  static revokePendingTimelock(): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("revokePendingTimelock");
  }

  /* SUPPLY CAP */

  static submitCap(marketParams: MarketParamsStruct, newSupplyCap: BigNumberish): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("submitCap", [marketParams, newSupplyCap]);
  }

  static acceptCap(marketParams: MarketParamsStruct): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("acceptCap", [marketParams]);
  }

  static revokePendingCap(id: string): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("revokePendingCap", [id]);
  }

  /* FORCED MARKET REMOVAL */

  static submitMarketRemoval(marketParams: MarketParamsStruct): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("submitMarketRemoval", [marketParams]);
  }

  static revokePendingMarketRemoval(id: string): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("revokePendingMarketRemoval", [id]);
  }

  /* GUARDIAN */

  static submitGuardian(newGuardian: string): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("submitGuardian", [newGuardian]);
  }

  static acceptGuardian(): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("acceptGuardian");
  }

  static revokePendingGuardian(): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("revokePendingGuardian");
  }

  /* MANAGEMENT */

  static skim(erc20: string): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("skim", [erc20]);
  }

  static setSupplyQueue(supplyQueue: string[]): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("setSupplyQueue", [supplyQueue]);
  }

  static updateWithdrawQueue(indexes: BigNumberish[]): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("updateWithdrawQueue", [indexes]);
  }

  static reallocate(allocations: MarketAllocationStruct[]): MetaMorphoCall {
    return MetaMorphoAction.METAMORPHO_IFC.encodeFunctionData("reallocate", [allocations]);
  }
}

export default MetaMorphoAction;
