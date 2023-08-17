import { BigNumberish } from "ethers";
import { BaseBundler__factory } from "types";

import { BulkCall } from "./BulkAction";

export class BulkBatch {
  private static BASE_BUNDLER_IFC = BaseBundler__factory.createInterface();

  static batch(deadline: BigNumberish, calls: BulkCall[]) {
    return BulkBatch.BASE_BUNDLER_IFC.encodeFunctionData("multicall", [deadline, calls]);
  }
}
