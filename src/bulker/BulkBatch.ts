import { ParamType, defaultAbiCoder } from "@ethersproject/abi";
import { IBlueBulker } from "types";

export class BulkBatch {
  static encode(actions: IBlueBulker.ActionStruct[]): string {
    return defaultAbiCoder.encode(
      [
        ParamType.from({
          type: "tuple[]",
          components: [
            ParamType.from({ name: "actionType", type: "uint256" }),
            ParamType.from({ name: "data", type: "bytes" }),
          ],
        }),
      ],
      [actions],
    );
  }
}
