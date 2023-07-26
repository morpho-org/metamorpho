import { ParamType, defaultAbiCoder } from "@ethersproject/abi";
import { BigNumberish, Signature } from "ethers";
import { IBlueBulker } from "types";
import { MarketStruct } from "types/contracts/interfaces/IBlue";
import { BulkBatch } from "./BulkBatch";

// These must be defined in the order they are defined in Solidity.
enum BulkActionType {
  APPROVE2,
  TRANSFER_FROM2,
  SET_APPROVAL,
  SUPPLY,
  SUPPLY_COLLATERAL,
  BORROW,
  REPAY,
  WITHDRAW,
  WITHDRAW_COLLATERAL,
  WRAP_ETH,
  UNWRAP_ETH,
  WRAP_ST_ETH,
  UNWRAP_ST_ETH,
  SKIM,
}

const marketParamtype = ParamType.from({
  type: "tuple",
  components: [
    ParamType.from({ name: "collateralAsset", type: "address" }),
    ParamType.from({ name: "borrowableAsset", type: "address" }),
    ParamType.from({ name: "collateralOracle", type: "address" }),
    ParamType.from({ name: "borrowableOracle", type: "address" }),
    ParamType.from({ name: "irm", type: "address" }),
    ParamType.from({ name: "lltv", type: "uint256" }),
  ],
});

class BulkAction {
  static approve2(
    asset: string,
    amount: BigNumberish,
    deadline: BigNumberish,
    signature: Signature,
  ): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.APPROVE2,
      data: defaultAbiCoder.encode(
        [
          "address",
          "uint256",
          "uint256",
          ParamType.from({
            type: "tuple",
            components: [
              ParamType.from({ name: "v", type: "uint8" }),
              ParamType.from({ name: "s", type: "bytes32" }),
              ParamType.from({ name: "r", type: "bytes32" }),
            ],
          }),
        ],
        [asset, amount, deadline, { v: signature.v, r: signature.r, s: signature.s }],
      ),
    };
  }

  static transferFrom2(asset: string, amount: BigNumberish): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.TRANSFER_FROM2,
      data: defaultAbiCoder.encode(["address", "uint256"], [asset, amount]),
    };
  }

  static setApproval(
    isApproved: boolean,
    nonce: BigNumberish,
    deadline: BigNumberish,
    signature: Signature,
  ): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.SET_APPROVAL,
      data: defaultAbiCoder.encode(
        [
          "bool",
          "uint256",
          "uint256",
          ParamType.from({
            type: "tuple",
            components: [
              ParamType.from({ name: "v", type: "uint8" }),
              ParamType.from({ name: "s", type: "bytes32" }),
              ParamType.from({ name: "r", type: "bytes32" }),
            ],
          }),
        ],
        [isApproved, nonce, deadline, { v: signature.v, r: signature.r, s: signature.s }],
      ),
    };
  }

  static supply(
    market: MarketStruct,
    amount: BigNumberish,
    onBehalf: string,
  ): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.SUPPLY,
      data: defaultAbiCoder.encode(
        [marketParamtype, "uint256", "address"],
        [market, amount, onBehalf],
      ),
    };
  }

  static supplyCollateral(
    market: MarketStruct,
    amount: BigNumberish,
    onBehalf: string,
    callbackActions: IBlueBulker.ActionStruct[],
  ): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.SUPPLY_COLLATERAL,
      data: defaultAbiCoder.encode(
        [marketParamtype, "uint256", "address", "bytes"],
        [market, amount, onBehalf, BulkBatch.encode(callbackActions)],
      ),
    };
  }

  static borrow(
    market: MarketStruct,
    amount: BigNumberish,
    receiver: string,
  ): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.BORROW,
      data: defaultAbiCoder.encode(
        [marketParamtype, "uint256", "address"],
        [market, amount, receiver],
      ),
    };
  }

  static repay(
    market: MarketStruct,
    amount: BigNumberish,
    onBehalf: string,
    callbackActions: IBlueBulker.ActionStruct[],
  ): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.REPAY,
      data: defaultAbiCoder.encode(
        [marketParamtype, "uint256", "address", "bytes"],
        [market, amount, onBehalf, BulkBatch.encode(callbackActions)],
      ),
    };
  }

  static withdraw(
    market: MarketStruct,
    amount: BigNumberish,
    receiver: string,
  ): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.WITHDRAW,
      data: defaultAbiCoder.encode(
        [marketParamtype, "uint256", "address"],
        [market, amount, receiver],
      ),
    };
  }

  static withdrawCollateral(
    market: MarketStruct,
    amount: BigNumberish,
    receiver: string,
  ): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.WITHDRAW_COLLATERAL,
      data: defaultAbiCoder.encode(
        [marketParamtype, "uint256", "address"],
        [market, amount, receiver],
      ),
    };
  }

  static wrapEth(amount: BigNumberish): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.WRAP_ETH,
      data: defaultAbiCoder.encode(["uint256"], [amount]),
    };
  }

  static unwrapEth(amount: BigNumberish, receiver: string): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.UNWRAP_ETH,
      data: defaultAbiCoder.encode(["uint256", "address"], [amount, receiver]),
    };
  }

  static wrapStEth(amount: BigNumberish): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.WRAP_ST_ETH,
      data: defaultAbiCoder.encode(["uint256"], [amount]),
    };
  }

  static unwrapStEth(amount: BigNumberish, receiver: string): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.UNWRAP_ST_ETH,
      data: defaultAbiCoder.encode(["uint256", "address"], [amount, receiver]),
    };
  }

  static skim(asset: string, receiver: string): IBlueBulker.ActionStruct {
    return {
      actionType: BulkActionType.SKIM,
      data: defaultAbiCoder.encode(["address", "address"], [asset, receiver]),
    };
  }
}

export default BulkAction;
