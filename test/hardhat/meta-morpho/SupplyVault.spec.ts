import { AbiCoder, MaxUint256, keccak256, toBigInt } from "ethers";
import hre from "hardhat";
import { ERC20Mock, IrmMock, OracleMock, SupplyVault } from "types";
import { IMorpho, MarketParamsStruct } from "types/@morpho-blue/interfaces/IMorpho";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

// Must use relative import path.
import MorphoArtifact from "../../../lib/morpho-blue/out/Morpho.sol/Morpho.json";

// Without the division it overflows.
const initBalance = MaxUint256 / 10000000000000000n;
const oraclePriceScale = 1000000000000000000000000000000000000n;

let seed = 42;
const random = () => {
  seed = (seed * 16807) % 2147483647;

  return (seed - 1) / 2147483646;
};

const identifier = (marketParams: MarketParamsStruct) => {
  const encodedMarket = AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "address", "address", "uint256"],
    Object.values(marketParams),
  );

  return Buffer.from(keccak256(encodedMarket).slice(2), "hex");
};

describe("Morpho", () => {
  let signers: SignerWithAddress[];
  let admin: SignerWithAddress;
  let liquidator: SignerWithAddress;

  let morpho: IMorpho;
  let borrowable: ERC20Mock;
  let collateral: ERC20Mock;
  let oracle: OracleMock;
  let irm: IrmMock;

  let supplyVault: SupplyVault;

  let marketParams: MarketParamsStruct;
  let id: Buffer;

  const updateMarket = (newMarket: Partial<MarketParamsStruct>) => {
    marketParams = { ...marketParams, ...newMarket };
    id = identifier(marketParams);
  };

  beforeEach(async () => {
    const allSigners = await hre.ethers.getSigners();

    signers = allSigners.slice(0, -2);
    [admin, liquidator] = allSigners.slice(-2);

    const ERC20MockFactory = await hre.ethers.getContractFactory("ERC20Mock", admin);

    borrowable = await ERC20MockFactory.deploy("DAI", "DAI");
    collateral = await ERC20MockFactory.deploy("Wrapped BTC", "WBTC");

    const OracleMockFactory = await hre.ethers.getContractFactory("OracleMock", admin);

    oracle = await OracleMockFactory.deploy();

    await oracle.setPrice(oraclePriceScale);

    const MorphoFactory = await hre.ethers.getContractFactory(
      MorphoArtifact.abi,
      MorphoArtifact.bytecode.object,
      admin,
    );

    morpho = (await MorphoFactory.deploy(admin.address)) as IMorpho;

    const IrmMockFactory = await hre.ethers.getContractFactory("IrmMock", admin);

    irm = await IrmMockFactory.deploy();

    const borrowableAddress = await borrowable.getAddress();

    updateMarket({
      borrowableToken: borrowableAddress,
      collateralToken: await collateral.getAddress(),
      oracle: await oracle.getAddress(),
      irm: await irm.getAddress(),
      lltv: BigInt.WAD / 2n + 1n,
    });

    await morpho.enableLltv(marketParams.lltv);
    await morpho.enableIrm(marketParams.irm);
    await morpho.createMarket(marketParams);

    const morphoAddress = await morpho.getAddress();

    for (const signer of signers) {
      await borrowable.setBalance(signer.address, initBalance);
      await borrowable.connect(signer).approve(morphoAddress, MaxUint256);
      await collateral.setBalance(signer.address, initBalance);
      await collateral.connect(signer).approve(morphoAddress, MaxUint256);
    }

    await borrowable.setBalance(admin.address, initBalance);
    await borrowable.connect(admin).approve(morphoAddress, MaxUint256);

    await borrowable.setBalance(liquidator.address, initBalance);
    await borrowable.connect(liquidator).approve(morphoAddress, MaxUint256);

    const SupplyVaultFactory = await hre.ethers.getContractFactory("SupplyVault", admin);

    supplyVault = await SupplyVaultFactory.deploy(morphoAddress, borrowableAddress, "SupplyVault", "mB");
  });

  it("should simulate gas cost [main]", async () => {
    for (let i = 0; i < signers.length; ++i) {
      console.log("[main]", i, "/", signers.length);

      const user = signers[i];

      let assets = BigInt.WAD * toBigInt(1 + Math.floor(random() * 100));

      // await supplyVault.connect(user).deposit(marketParams, assets, 0, user.address, "0x");
      // await supplyVault.connect(user).withdraw(marketParams, assets / 2n, 0, user.address, user.address);

      // const market = await morpho.market(id);
      // const liquidity = market.totalSupplyAssets - market.totalBorrowAssets;

      // assets = BigInt.min(assets, liquidity / 2n);

      // await morpho.connect(user).supplyCollateral(marketParams, assets, user.address, "0x");
      // await morpho.connect(user).borrow(marketParams, assets / 2n, 0, user.address, user.address);
      // await morpho.connect(user).repay(marketParams, assets / 4n, 0, user.address, "0x");
      // await morpho.connect(user).withdrawCollateral(marketParams, assets / 8n, user.address, user.address);
    }

    await hre.network.provider.send("evm_setAutomine", [true]);
  });
});
