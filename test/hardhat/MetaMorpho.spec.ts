import { AbiCoder, MaxUint256, keccak256, toBigInt } from "ethers";
import hre from "hardhat";
import _range from "lodash/range";
import { ERC20Mock, IrmMock, OracleMock, MetaMorpho } from "types";
import { IMorpho, MarketParamsStruct } from "types/@morpho-blue/interfaces/IMorpho";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { setNextBlockTimestamp } from "@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time";

// Must use relative import path.
import MorphoArtifact from "../../lib/morpho-blue/out/Morpho.sol/Morpho.json";

// Without the division it overflows.
const initBalance = MaxUint256 / 10000000000000000n;
const oraclePriceScale = 1000000000000000000000000000000000000n;
const nbMarkets = 5;

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

const logProgress = (name: string, i: number, max: number) => {
  if (i % 10 == 0) console.log("[" + name + "]", Math.floor((100 * i) / max), "%");
};

const randomForwardTimestamp = async () => {
  const block = await hre.ethers.provider.getBlock("latest");
  const elapsed = random() < 1 / 2 ? 0 : (1 + Math.floor(random() * 100)) * 12; // 50% of the time, don't go forward in time.

  await setNextBlockTimestamp(block!.timestamp + elapsed);
};

describe("MetaMorpho", () => {
  let admin: SignerWithAddress;
  let riskManager: SignerWithAddress;
  let allocator: SignerWithAddress;
  let suppliers: SignerWithAddress[];
  let borrowers: SignerWithAddress[];

  let morpho: IMorpho;
  let borrowable: ERC20Mock;
  let collateral: ERC20Mock;
  let oracle: OracleMock;
  let irm: IrmMock;

  let metaMorpho: MetaMorpho;

  let allMarketParams: MarketParamsStruct[];

  beforeEach(async () => {
    const allSigners = await hre.ethers.getSigners();

    const users = allSigners.slice(0, -3);

    [admin, riskManager, allocator] = allSigners.slice(-3);
    suppliers = users.slice(0, users.length / 2);
    borrowers = users.slice(users.length / 2);

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

    const morphoAddress = await morpho.getAddress();
    const borrowableAddress = await borrowable.getAddress();
    const collateralAddress = await collateral.getAddress();
    const oracleAddress = await oracle.getAddress();
    const irmAddress = await irm.getAddress();

    allMarketParams = _range(1, 1 + nbMarkets).map((i) => ({
      borrowableToken: borrowableAddress,
      collateralToken: collateralAddress,
      oracle: oracleAddress,
      irm: irmAddress,
      lltv: (BigInt.WAD * toBigInt(i)) / toBigInt(i + 1), // lltv >= 50%
    }));

    await morpho.enableIrm(irmAddress);

    for (const marketParams of allMarketParams) {
      await morpho.enableLltv(marketParams.lltv);
      await morpho.createMarket(marketParams);
    }

    const IMetaMorphoFactory = await hre.ethers.getContractFactory("MetaMorpho", admin);

    metaMorpho = await IMetaMorphoFactory.deploy(morphoAddress, 1, borrowableAddress, "MetaMorpho", "mB");

    const metaMorphoAddress = await metaMorpho.getAddress();

    for (const user of users) {
      await borrowable.setBalance(user.address, initBalance);
      await borrowable.connect(user).approve(metaMorphoAddress, MaxUint256);
      await collateral.setBalance(user.address, initBalance);
      await collateral.connect(user).approve(morphoAddress, MaxUint256);
    }

    await metaMorpho.setIsRiskManager(riskManager.address, true);
    await metaMorpho.setIsAllocator(allocator.address, true);

    await metaMorpho.submitTimelock(0);

    const block = await hre.ethers.provider.getBlock("latest");
    await setNextBlockTimestamp(block!.timestamp + 1);

    await metaMorpho.acceptTimelock();

    await metaMorpho.setFeeRecipient(admin.address);
    await metaMorpho.submitFee(BigInt.WAD / 10n);

    for (const marketParams of allMarketParams) {
      await metaMorpho
        .connect(riskManager)
        .submitCap(marketParams, (BigInt.WAD * 100n * toBigInt(suppliers.length)) / toBigInt(allMarketParams.length));
    }

    await metaMorpho.connect(riskManager).setSupplyQueue(allMarketParams.map(identifier));
    await metaMorpho.connect(riskManager).sortWithdrawQueue(allMarketParams.map((_, i) => nbMarkets - 1 - i));

    hre.tracer.nameTags[morphoAddress] = "Morpho";
    hre.tracer.nameTags[collateralAddress] = "Collateral";
    hre.tracer.nameTags[borrowableAddress] = "Borrowable";
    hre.tracer.nameTags[oracleAddress] = "Oracle";
    hre.tracer.nameTags[irmAddress] = "IRM";
    hre.tracer.nameTags[metaMorphoAddress] = "MetaMorpho";
  });

  it("should simulate gas cost [main]", async () => {
    for (let i = 0; i < suppliers.length; ++i) {
      logProgress("main", i, suppliers.length);

      const supplier = suppliers[i];

      let assets = BigInt.WAD * toBigInt(1 + Math.floor(random() * 100));

      await randomForwardTimestamp();

      await metaMorpho.connect(supplier).deposit(assets, supplier.address);

      await randomForwardTimestamp();

      await metaMorpho.connect(supplier).withdraw(assets / 2n, supplier.address, supplier.address);

      await randomForwardTimestamp();

      await metaMorpho.connect(allocator).reallocate(
        [{ marketParams: allMarketParams[0], assets: assets / 2n }],
        allMarketParams.map((marketParams) => ({ marketParams, assets: assets / toBigInt(nbMarkets + 1) / 2n })),
      );

      const borrower = borrowers[i];

      for (const marketParams of allMarketParams) {
        const market = await morpho.market(identifier(marketParams));
        const liquidity = market.totalSupplyAssets - market.totalBorrowAssets;

        assets = liquidity / 2n;

        await randomForwardTimestamp();

        await morpho.connect(borrower).supplyCollateral(marketParams, assets, borrower.address, "0x");

        await randomForwardTimestamp();

        await morpho.connect(borrower).borrow(marketParams, assets / 3n, 0, borrower.address, borrower.address);
      }
    }
  });
});
