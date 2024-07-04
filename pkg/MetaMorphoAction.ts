import { BigNumberish } from "ethers";
import { MetaMorpho__factory } from "types";
import { MarketAllocationStruct, MarketParamsStruct } from "types/src/MetaMorpho";

const METAMORPHO_IFC = MetaMorpho__factory.createInterface();

export type MetaMorphoCall = string;

export namespace MetaMorphoAction {
  /* CONFIGURATION */

  /**
   * Encodes a call to a MetaMorpho instance to set the curator.
   * @param newCurator The address of the new curator.
   */
  export function setCurator(newCurator: string): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("setCurator", [newCurator]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to enable or disable an allocator.
   * @param newAllocator The address of the allocator.
   * @param newIsAllocator Whether the allocator should be enabled or disabled.
   */
  export function setIsAllocator(newAllocator: string, newIsAllocator: boolean): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("setIsAllocator", [newAllocator, newIsAllocator]);
  }

  /**
   * Encode a call to a MetaMorpho instance to set the fee recipient.
   * @param newFeeRecipient The address of the new fee recipient.
   */
  export function setFeeRecipient(newFeeRecipient: string): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("setFeeRecipient", [newFeeRecipient]);
  }

  /**
   * Encode a call to a MetaMorpho instance to set the skim recipient.
   * @param newSkimRecipient The address of the new skim recipient.
   */
  export function setSkimRecipient(newSkimRecipient: string): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("setSkimRecipient", [newSkimRecipient]);
  }

  /**
   * Encode a call to a MetaMorpho instance to set the fee.
   * @param fee The new fee percentage (in WAD).
   */
  export function setFee(fee: BigNumberish): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("setFee", [fee]);
  }

  /* TIMELOCK */

  /**
   * Encodes a call to a MetaMorpho instance to submit a new timelock.
   * @param newTimelock The new timelock (in seconds).
   */
  export function submitTimelock(newTimelock: BigNumberish): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("submitTimelock", [newTimelock]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to accept the pending timelock.
   */
  export function acceptTimelock(): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("acceptTimelock");
  }

  /**
   * Encodes a call to a MetaMorpho instance to revoke the pending timelock.
   */
  export function revokePendingTimelock(): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("revokePendingTimelock");
  }

  /* SUPPLY CAP */

  /**
   * Encodes a call to a MetaMorpho instance to submit a new supply cap.
   * @param marketParams The market params of the market of which to submit a supply cap.
   * @param newSupplyCap The new supply cap.
   */
  export function submitCap(marketParams: MarketParamsStruct, newSupplyCap: BigNumberish): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("submitCap", [marketParams, newSupplyCap]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to accept the pending supply cap.
   * @param marketParams The market params of the market of which to accept the pending supply cap.
   */
  export function acceptCap(marketParams: MarketParamsStruct): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("acceptCap", [marketParams]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to revoke the pending supply cap.
   * @param id The id of the market of which to revoke the pending supply cap.
   */
  export function revokePendingCap(id: string): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("revokePendingCap", [id]);
  }

  /* FORCED MARKET REMOVAL */

  /**
   * Encodes a call to a MetaMorpho instance to submit a market removal.
   * @param marketParams The market params of the market to remove.
   */
  export function submitMarketRemoval(marketParams: MarketParamsStruct): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("submitMarketRemoval", [marketParams]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to accept the pending market removal.
   * @param id The id of the market of which to accept the removal.
   */
  export function revokePendingMarketRemoval(id: string): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("revokePendingMarketRemoval", [id]);
  }

  /* GUARDIAN */

  /**
   * Encodes a call to a MetaMorpho instance to submit a new guardian.
   * @param newGuardian The address of the new guardian.
   */
  export function submitGuardian(newGuardian: string): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("submitGuardian", [newGuardian]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to accept the pending guardian.
   */
  export function acceptGuardian(): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("acceptGuardian");
  }

  /**
   * Encodes a call to a MetaMorpho instance to revoke the pending guardian.
   */
  export function revokePendingGuardian(): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("revokePendingGuardian");
  }

  /* MANAGEMENT */

  /**
   * Encodes a call to a MetaMorpho instance to skim ERC20 tokens.
   * @param erc20 The address of the ERC20 token to skim.
   */
  export function skim(erc20: string): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("skim", [erc20]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to set the supply queue.
   * @param supplyQueue The new supply queue.
   */
  export function setSupplyQueue(supplyQueue: string[]): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("setSupplyQueue", [supplyQueue]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to update the withdraw queue.
   * @param indexes The indexes of each market in the previous withdraw queue, in the new withdraw queue's order.
   */
  export function updateWithdrawQueue(indexes: BigNumberish[]): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("updateWithdrawQueue", [indexes]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to reallocate the vault's liquidity across enabled markets.
   * @param allocations The new target allocations of each market.
   */
  export function reallocate(allocations: MarketAllocationStruct[]): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("reallocate", [allocations]);
  }

  /* ERC4626 */

  /**
   * Encodes a call to a MetaMorpho instance to mint shares.
   * @param shares The amount of shares to mint.
   * @param receiver The address of the receiver of the shares.
   */
  export function mint(shares: BigNumberish, receiver: string): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("mint", [shares, receiver]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to deposit assets.
   * @param assets The amount of assets to deposit.
   * @param receiver The address of the receiver of the shares.
   */
  export function deposit(assets: BigNumberish, receiver: string): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("deposit", [assets, receiver]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to withdraw assets.
   * @param assets The amount of assets to withdraw.
   * @param receiver The address of the receiver of the assets.
   * @param owner The address of the owner of the shares to redeem.
   */
  export function withdraw(assets: BigNumberish, receiver: string, owner: string): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("withdraw", [assets, receiver, owner]);
  }

  /**
   * Encodes a call to a MetaMorpho instance to redeem shares.
   * @param shares The amount of shares to redeem.
   * @param receiver The address of the receiver of the assets.
   * @param owner The address of the owner of the shares to redeem.
   */
  export function redeem(shares: BigNumberish, receiver: string, owner: string): MetaMorphoCall {
    return METAMORPHO_IFC.encodeFunctionData("redeem", [shares, receiver, owner]);
  }
}

export default MetaMorphoAction;
