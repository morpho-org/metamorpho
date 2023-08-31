import { BigNumberish } from "ethers";
import { BaseBundler__factory } from "src/types";

import { BundleCall } from "./BundleAction";

export class BundleBatch {
  private static BASE_BUNDLER_IFC = BaseBundler__factory.createInterface();

  static batch(deadline: BigNumberish, calls: BundleCall[]) {
    return BundleBatch.BASE_BUNDLER_IFC.encodeFunctionData("multicall", [deadline, calls]);
  }
}
