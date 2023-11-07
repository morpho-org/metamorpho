import { AbiCoder, MaxUint256, ZeroHash, keccak256, toBigInt } from "ethers";
import hre from "hardhat";
import _range from "lodash/range";
import { ERC20Mock, OracleMock, MetaMorpho, IMorpho, MetaMorphoFactory, MetaMorpho__factory, IrmMock } from "types";
import { MarketParamsStruct } from "types/@morpho-blue/interfaces/IMorpho";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { mine } from "@nomicfoundation/hardhat-network-helpers";
import {
  increaseTo,
  latest,
  setNextBlockTimestamp,
} from "@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time";

// Must use relative import path.
import MorphoArtifact from "../../lib/morpho-blue/out/Morpho.sol/Morpho.json";

// Without the division it overflows.
const initBalance = MaxUint256 / 10000000000000000n;
const oraclePriceScale = 1000000000000000000000000000000000000n;
const nbMarkets = 5;
const timelock = 3600 * 24 * 7; // 1 week.

const ln2 = 693147180559945309n;
const targetUtilization = 800000000000000000n;
const speedFactor = 277777777777n;
const initialRate = 317097920n;

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

const forwardTimestamp = async (elapsed: number) => {
  const timestamp = await latest();
  const newTimestamp = timestamp + elapsed;

  await increaseTo(newTimestamp);
  await setNextBlockTimestamp(newTimestamp);
};

const randomForwardTimestamp = async () => {
  const elapsed = random() < 1 / 2 ? 0 : (1 + Math.floor(random() * 100)) * 12; // 50% of the time, don't go forward in time.

  await forwardTimestamp(elapsed);
};

describe("MetaMorpho", () => {
  let admin: SignerWithAddress;
  let curator: SignerWithAddress;
  let allocator: SignerWithAddress;
  let suppliers: SignerWithAddress[];
  let borrowers: SignerWithAddress[];

  let morpho: IMorpho;
  let loan: ERC20Mock;
  let collateral: ERC20Mock;
  let oracle: OracleMock;
  let irm: IrmMock;

  let factory: MetaMorphoFactory;
  let metaMorpho: MetaMorpho;
  let metaMorphoAddress: string;

  let supplyCap: bigint;
  let allMarketParams: MarketParamsStruct[];

  const expectedMarket = async (marketParams: MarketParamsStruct) => {
    const id = identifier(marketParams);
    const rawMarket = await morpho.market(id);

    const market = {
      totalSupplyAssets: rawMarket.totalSupplyAssets,
      totalBorrowAssets: rawMarket.totalBorrowAssets,
      totalSupplyShares: rawMarket.totalSupplyShares,
      totalBorrowShares: rawMarket.totalBorrowShares,
      lastUpdate: rawMarket.lastUpdate,
      fee: rawMarket.fee,
    };

    // Cannot use another timestamp because `borrowRateView` relies on `block.timestamp`.
    const timestamp = toBigInt(await latest());
    const elapsed = timestamp - market.lastUpdate;

    if (elapsed > 0n && market.totalBorrowAssets > 0n) {
      const borrowRate = await irm.borrowRateView(marketParams, market);
      const interest = market.totalBorrowAssets.wadMulDown((borrowRate * elapsed).wadExpN(3) - BigInt.WAD);

      market.totalBorrowAssets += interest;
      market.totalSupplyAssets += interest;

      if (market.fee > 0n) {
        const feeAmount = interest.wadMulDown(market.fee);
        const feeShares = feeAmount.toSharesDown(market.totalSupplyAssets - feeAmount, market.totalSupplyShares);

        market.totalSupplyShares += feeShares;
      }
    }

    market.lastUpdate = timestamp;

    return market;
  };

  beforeEach(async () => {
    const allSigners = await hre.ethers.getSigners();

    const users = allSigners.slice(0, -3);

    [admin, curator, allocator] = allSigners.slice(-3);
    suppliers = users.slice(0, users.length / 2);
    borrowers = users.slice(users.length / 2);

    const ERC20MockFactory = await hre.ethers.getContractFactory("ERC20Mock", admin);

    loan = await ERC20MockFactory.deploy("DAI", "DAI");
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

    const morphoAddress = await morpho.getAddress();

    const IrmMockFactory = await hre.ethers.getContractFactory("IrmMock", admin);

    irm = await IrmMockFactory.deploy();

    await irm.setApr(BigInt.WAD / 100n); // 1%

    const loanAddress = await loan.getAddress();
    const collateralAddress = await collateral.getAddress();
    const oracleAddress = await oracle.getAddress();
    const irmAddress = await irm.getAddress();

    allMarketParams = _range(1, 1 + nbMarkets).map((i) => ({
      loanToken: loanAddress,
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

    const MetaMorphoFactoryFactory = await hre.ethers.getContractFactory("MetaMorphoFactory", admin);

    factory = await MetaMorphoFactoryFactory.deploy(morphoAddress);

    metaMorphoAddress = await factory.createMetaMorpho.staticCall(
      admin.address,
      timelock,
      loanAddress,
      "MetaMorpho",
      "mB",
      ZeroHash,
    );

    metaMorpho = MetaMorpho__factory.connect(metaMorphoAddress, admin);

    await factory.createMetaMorpho(admin.address, timelock, loanAddress, "MetaMorpho", "mB", ZeroHash);

    for (const user of users) {
      await loan.setBalance(user.address, initBalance);
      await loan.connect(user).approve(metaMorphoAddress, MaxUint256);
      await collateral.setBalance(user.address, initBalance);
      await collateral.connect(user).approve(morphoAddress, MaxUint256);
    }

    await metaMorpho.setCurator(curator.address);
    await metaMorpho.setIsAllocator(allocator.address, true);

    await metaMorpho.setFeeRecipient(admin.address);
    await metaMorpho.submitFee(BigInt.WAD / 10n);

    await forwardTimestamp(timelock);
    await metaMorpho.connect(admin).acceptFee();

    supplyCap = (BigInt.WAD * 20n * toBigInt(suppliers.length)) / toBigInt(nbMarkets);
    for (const marketParams of allMarketParams) {
      await metaMorpho.connect(curator).submitCap(marketParams, supplyCap);
    }

    await forwardTimestamp(timelock);

    for (const marketParams of allMarketParams) {
      await metaMorpho.connect(admin).acceptCap(identifier(marketParams));
    }

    await metaMorpho.connect(curator).setSupplyQueue(allMarketParams.map(identifier));
    await metaMorpho.connect(curator).updateWithdrawQueue(allMarketParams.map((_, i) => nbMarkets - 1 - i));

    hre.tracer.nameTags[morphoAddress] = "Morpho";
    hre.tracer.nameTags[collateralAddress] = "Collateral";
    hre.tracer.nameTags[loanAddress] = "Loan";
    hre.tracer.nameTags[oracleAddress] = "Oracle";
    hre.tracer.nameTags[irmAddress] = "IRM";
    hre.tracer.nameTags[metaMorphoAddress] = "MetaMorpho";
  });

  it("should simulate gas cost [main]", async () => {
    for (let i = 0; i < suppliers.length; ++i) {
      logProgress("main", i, suppliers.length);

      const supplier = suppliers[i];
      const assets = BigInt.WAD * toBigInt(1 + Math.floor(random() * 100));

      await randomForwardTimestamp();

      await metaMorpho.connect(supplier).deposit(assets, supplier.address);

      await randomForwardTimestamp();

      await metaMorpho.connect(supplier).withdraw(assets / 2n, supplier.address, supplier.address);

      await randomForwardTimestamp();

      const allocation = await Promise.all(
        allMarketParams.map(async (marketParams) => {
          const market = await expectedMarket(marketParams);
          const position = await morpho.position(identifier(marketParams), metaMorphoAddress);

          return {
            marketParams,
            market,
            liquidity: market.totalSupplyAssets - market.totalBorrowAssets,
            supplyAssets: position.supplyShares.toAssetsDown(market.totalSupplyAssets, market.totalSupplyShares),
          };
        }),
      );

      const withdrawn = allocation
        .map(({ marketParams, liquidity, supplyAssets }) => ({
          marketParams,
          // Always withdraw all, up to the liquidity.
          assets: liquidity > supplyAssets ? MaxUint256 : liquidity,
        }))
        .filter(({ assets }) => assets > 0n);

      const withdrawnAssets = allocation.reduce(
        (total, { supplyAssets, liquidity }) => total + supplyAssets.min(liquidity),
        0n,
      );

      // Always consider 90% of withdrawn assets because rates go brrrr.
      const marketAssets = (withdrawnAssets * 9n) / 10n / toBigInt(nbMarkets);

      const supplied = allocation
        .map(({ marketParams }) => ({
          marketParams,
          // Always supply evenly on each market 90% of what the vault withdrawn in total.
          assets: marketAssets,
        }))
        .filter(({ assets }) => assets > 0n);

      await metaMorpho.connect(allocator).reallocate(withdrawn, supplied);

      // Borrow liquidity to generate interest.

      await hre.network.provider.send("evm_setAutomine", [false]);

      const borrower = borrowers[i];

      for (const marketParams of allMarketParams) {
        await randomForwardTimestamp();

        const market = await expectedMarket(marketParams);

        const liquidity = market.totalSupplyAssets - market.totalBorrowAssets;
        const borrowed = liquidity / 3n;
        if (borrowed === 0n) break;

        await morpho.connect(borrower).supplyCollateral(marketParams, liquidity, borrower.address, "0x");
        await morpho.connect(borrower).borrow(marketParams, borrowed, 0, borrower.address, borrower.address);

        await mine(); // Include supplyCollateral + borrow in a single block.
      }

      await hre.network.provider.send("evm_setAutomine", [true]);
    }
  });
});
