import * as dotenv from "dotenv";
import { BigNumberish, toBigInt } from "ethers";
import "evm-maths";
import { getConvertToAssets, getConvertToShares, mulDivDown, mulDivUp } from "evm-maths/lib/utils";
import "hardhat-gas-reporter";
import "hardhat-tracer";
import { HardhatUserConfig } from "hardhat/config";
import "solidity-coverage";

import "@nomicfoundation/hardhat-chai-matchers";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-network-helpers";
import "@typechain/hardhat";

dotenv.config();

declare global {
  interface BigInt {
    toAssetsUp: (totalAssets: BigNumberish, totalShares: BigNumberish) => bigint;
    toAssetsDown: (totalAssets: BigNumberish, totalShares: BigNumberish) => bigint;
    toSharesUp: (totalAssets: BigNumberish, totalShares: BigNumberish) => bigint;
    toSharesDown: (totalAssets: BigNumberish, totalShares: BigNumberish) => bigint;
  }
}

const virtualAssets = 1n;
const virtualShares = 100000n;

const toAssetsUp = getConvertToAssets(virtualAssets, virtualShares, mulDivUp);
const toAssetsDown = getConvertToAssets(virtualAssets, virtualShares, mulDivDown);
const toSharesUp = getConvertToShares(virtualAssets, virtualShares, mulDivUp);
const toSharesDown = getConvertToShares(virtualAssets, virtualShares, mulDivDown);

BigInt.prototype.toAssetsUp = function (totalAssets: BigNumberish, totalShares: BigNumberish) {
  return toAssetsUp(this as bigint, toBigInt(totalAssets), toBigInt(totalShares));
};
BigInt.prototype.toAssetsDown = function (totalAssets: BigNumberish, totalShares: BigNumberish) {
  return toAssetsDown(this as bigint, toBigInt(totalAssets), toBigInt(totalShares));
};
BigInt.prototype.toSharesUp = function (totalAssets: BigNumberish, totalShares: BigNumberish) {
  return toSharesUp(this as bigint, toBigInt(totalAssets), toBigInt(totalShares));
};
BigInt.prototype.toSharesDown = function (totalAssets: BigNumberish, totalShares: BigNumberish) {
  return toSharesDown(this as bigint, toBigInt(totalAssets), toBigInt(totalShares));
};

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1,
      gasPrice: 0,
      initialBaseFeePerGas: 0,
      allowBlocksWithSameTimestamp: true,
      accounts: {
        count: 53, // must be odd
      },
      mining: {
        mempool: {
          order: "fifo",
        },
      },
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.21",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
          evmVersion: "paris",
        },
      },
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999,
          },
          viaIR: true,
          evmVersion: "paris",
        },
      },
    ],
  },
  mocha: {
    timeout: 3000000,
  },
  typechain: {
    target: "ethers-v6",
    outDir: "types/",
    externalArtifacts: ["deps/**/*.json"],
  },
  tracer: {
    defaultVerbosity: 1,
    gasCost: true,
  },
};

export default config;
