import { BigNumberish } from "ethers";
import { BaseBundler__factory } from "types";

import { BundlerCall } from "./BundlerAction";

export class BundlerBatch {
  private static BASE_BUNDLER_IFC = BaseBundler__factory.createInterface();

  static batch(deadline: BigNumberish, calls: BundlerCall[]) {
    return BundlerBatch.BASE_BUNDLER_IFC.encodeFunctionData("multicall", [deadline, calls]);
  }
}
