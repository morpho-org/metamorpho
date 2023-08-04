import { BigNumberish } from "ethers";
import { BaseBulker__factory } from "types";
import { BulkCall } from "./BulkAction";

export class BulkBatch {
  private static BASE_BULKER_IFC = BaseBulker__factory.createInterface();

  static batch(deadline: BigNumberish, calls: BulkCall[]) {
    return BulkBatch.BASE_BULKER_IFC.encodeFunctionData("multicall", [deadline, calls]);
  }
}
