import { allocate, narrow } from "./allocation";
import { totalProfit } from "./utils";

const L = 3000;

const pools: [number, number][] = [
  [20, 1000],
  [30, 2000],
  [20, 2000],
  [15, 3000],
];

const poolGasCost = 80_000; // arbitrary value
const gasPrice = 30e-9; // let's assume asset is ETH and gas price is 30 gwei

const { allocation: allocation1 } = allocate(L, pools);

console.log(allocation1, (totalProfit(allocation1, pools, poolGasCost * gasPrice) * 100) / L);

const allocation2 = narrow(allocation1, pools, poolGasCost * gasPrice);

console.log(allocation2, (totalProfit(allocation2, pools, poolGasCost * gasPrice) * 100) / L);
