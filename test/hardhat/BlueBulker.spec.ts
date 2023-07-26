import { defaultAbiCoder } from "@ethersproject/abi";
import { mine } from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, constants, utils } from "ethers";
import hre from "hardhat";

const initBalance = constants.MaxUint256.div(2);

let seed = 42;
const random = () => {
  seed = (seed * 16807) % 2147483647;

  return (seed - 1) / 2147483646;
};

const identifier = (market: Market) => {
  const encodedMarket = defaultAbiCoder.encode(
    ["address", "address", "address", "address", "address", "uint256"],
    Object.values(market),
  );

  return Buffer.from(utils.keccak256(encodedMarket).slice(2), "hex");
};

interface Market {
  borrowableAsset: string;
  collateralAsset: string;
  borrowableOracle: string;
  collateralOracle: string;
  irm: string;
  lltv: BigNumber;
}

describe("Blue", () => {
  let signers: SignerWithAddress[];
  let admin: SignerWithAddress;

  let market: Market;
  let id: Buffer;

  let nbLiquidations: number;

  const updateMarket = (newMarket: Partial<Market>) => {
    market = { ...market, ...newMarket };
    id = identifier(market);
  };
});
