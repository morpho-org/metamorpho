import { AbiCoder, MaxUint256, ZeroAddress, ZeroHash, keccak256, toBigInt } from "ethers";
import hre from "hardhat";
import _range from "lodash/range";
import { ERC20Mock, OracleMock, MetaMorpho, IMorpho, MetaMorphoFactory, MetaMorpho__factory, IIrm } from "types";
import { MarketParamsStruct } from "types/src/MetaMorpho";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { mine } from "@nomicfoundation/hardhat-network-helpers";
import {
  increaseTo,
  latest,
  setNextBlockTimestamp,
} from "@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time";

// Must use relative import path.
import AdaptiveCurveIrmArtifact from "../../lib/morpho-blue-irm/out/AdaptiveCurveIrm.sol/AdaptiveCurveIrm.json";
import MorphoArtifact from "../../lib/morpho-blue/out/Morpho.sol/Morpho.json";

// Without the division it overflows.
const initBalance = MaxUint256 / 10000000000000000n;
const oraclePriceScale = 1000000000000000000000000000000000000n;
const nbMarkets = 5;
const timelock = 3600 * 24 * 7; // 1 week.

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
  let irm: IIrm;

  let factory: MetaMorphoFactory;
  let metaMorpho: MetaMorpho;
  let metaMorphoAddress: string;

  let supplyCap: bigint;
  let allMarketParams: MarketParamsStruct[];
  let idleParams: MarketParamsStruct;

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
      const interest = market.totalBorrowAssets.wadMulDown((borrowRate * elapsed).wadExpN(3n) - BigInt.WAD);

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

    const AdaptiveCurveIrmFactory = await hre.ethers.getContractFactory(
      AdaptiveCurveIrmArtifact.abi,
      AdaptiveCurveIrmArtifact.bytecode.object,
      admin,
    );

    irm = (await AdaptiveCurveIrmFactory.deploy(morphoAddress)) as IIrm;

    const loanAddress = await loan.getAddress();
    const collateralAddress = await collateral.getAddress();
    const oracleAddress = await oracle.getAddress();
    const irmAddress = await irm.getAddress();

    idleParams = {
      loanToken: loanAddress,
      collateralToken: ZeroAddress,
      oracle: ZeroAddress,
      irm: irmAddress,
      lltv: 0n,
    };

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

    await morpho.enableLltv(idleParams.lltv);
    await morpho.createMarket(idleParams);

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
    await metaMorpho.setFee(BigInt.WAD / 10n);

    supplyCap = (BigInt.WAD * 50n * toBigInt(suppliers.length * 2)) / toBigInt(nbMarkets);

    for (const marketParams of allMarketParams) await metaMorpho.connect(curator).submitCap(marketParams, supplyCap);

    await metaMorpho.connect(curator).submitCap(idleParams, 2n ** 184n - 1n);

    await forwardTimestamp(timelock);

    await metaMorpho.connect(admin).acceptCap(idleParams);

    for (const marketParams of allMarketParams) {
      await metaMorpho.connect(admin).acceptCap(marketParams);
    }

    await metaMorpho.connect(curator).setSupplyQueue(
      // Set idle market last.
      allMarketParams.map(identifier).concat([identifier(idleParams)]),
    );
    await metaMorpho.connect(curator).updateWithdrawQueue(
      // Keep idle market first.
      [0].concat(allMarketParams.map((_, i) => nbMarkets - i)),
    );

    hre.tracer.nameTags[morphoAddress] = "Morpho";
    hre.tracer.nameTags[collateralAddress] = "Collateral";
    hre.tracer.nameTags[loanAddress] = "Loan";
    hre.tracer.nameTags[oracleAddress] = "Oracle";
    hre.tracer.nameTags[irmAddress] = "IRM";
    hre.tracer.nameTags[metaMorphoAddress] = "MetaMorpho";
  });

  it("should simulate gas cost [main]", async () => {
    const nbSuppliers = suppliers.length;
    const nbDeposits = nbSuppliers * 2;

    for (let i = 0; i < nbDeposits; ++i) {
      logProgress("main", i, nbDeposits);

      const j = i >= nbSuppliers ? nbDeposits - i - 1 : i;
      const supplier = suppliers[j];

      await randomForwardTimestamp();

      // Supplier j supplies twice, ~100 in total.
      await metaMorpho
        .connect(supplier)
        .deposit(
          BigInt.WAD * toBigInt(1 + Math.floor((99 * (nbDeposits - i - 1)) / (nbDeposits - 1))),
          supplier.address,
        );

      await randomForwardTimestamp();

      // Supplier j withdraws twice, ~80 in total.
      await metaMorpho
        .connect(supplier)
        .withdraw(
          BigInt.WAD * toBigInt(1 + Math.ceil((79 * i) / (nbDeposits - 1))),
          supplier.address,
          supplier.address,
        );

      await randomForwardTimestamp();

      const allocation = [];
      for (let marketParams of allMarketParams) {
        const market = await expectedMarket(marketParams);
        const position = await morpho.position(identifier(marketParams), metaMorphoAddress);

        allocation.push({
          marketParams,
          market,
          liquidity: market.totalSupplyAssets - market.totalBorrowAssets,
          supplyAssets: position.supplyShares.toAssetsDown(market.totalSupplyAssets, market.totalSupplyShares),
        });
      }

      const withdrawnAllocation = allocation.map(({ marketParams, liquidity, supplyAssets }) => {
        // Always withdraw all, up to the liquidity.
        const withdrawn = supplyAssets.min(liquidity);
        const remaining = supplyAssets - withdrawn;

        return {
          marketParams,
          supplyAssets,
          remaining,
          withdrawn,
        };
      });

      const idleMarket = await expectedMarket(idleParams);
      const idlePosition = await morpho.position(identifier(idleParams), metaMorphoAddress);

      const idleAssets = idlePosition.supplyShares.toAssetsDown(
        idleMarket.totalSupplyAssets,
        idleMarket.totalSupplyShares,
      );
      const withdrawnAssets = withdrawnAllocation.reduce((total, { withdrawn }) => total + withdrawn, 0n);

      const marketAssets = ((withdrawnAssets + idleAssets) * 9n) / 10n / toBigInt(nbMarkets);

      const allocations = withdrawnAllocation.map(({ marketParams, remaining }) => ({
        marketParams,
        // Always supply evenly on each market 90% of what the vault withdrawn in total.
        assets: remaining + marketAssets,
      }));

      await metaMorpho.connect(allocator).reallocate(
        // Always withdraw all from idle first.
        [{ marketParams: idleParams, assets: 0n }]
          .concat(allocations)
          // Always supply remaining to idle last.
          .concat([{ marketParams: idleParams, assets: MaxUint256 }]),
      );

      // Borrow liquidity to generate interest.

      await hre.network.provider.send("evm_setAutomine", [false]);

      const borrower = borrowers[i % nbSuppliers];

      for (const marketParams of allMarketParams) {
        await randomForwardTimestamp();

        const market = await expectedMarket(marketParams);

        const liquidity = market.totalSupplyAssets - market.totalBorrowAssets;
        const borrowed = liquidity / 100n;
        if (borrowed === 0n) break;

        await morpho.connect(borrower).supplyCollateral(marketParams, liquidity, borrower.address, "0x");
        await morpho.connect(borrower).borrow(marketParams, borrowed, 0, borrower.address, borrower.address);

        await mine(); // Include supplyCollateral + borrow in a single block.
      }

      await hre.network.provider.send("evm_setAutomine", [true]);
    }
  });
});
