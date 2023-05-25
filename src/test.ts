import { minimize } from "./gradient-descent";

const L = 100;
const dt = 1; // 1 year

const negPenaltySlope = 1e5;
const gasPenaltySlope = 1e5;
const gasPenaltyShift = 1e-4;

const poolGasCost = 50e5; // arbitrary value
const gasPrice = 30e-9; // let's assume asset is ETH and gas price is 30 gwei

const [a1, b1] = [20, 1000];
const [a2, b2] = [30, 2000];
const [a3, b3] = [20, 1500];
const [a4, b4] = [15, 3000];

const interests = (x: number, a: number, b: number) => (a / (b + x)) * x * dt;
const negPenalty = (x: number) => Math.exp(-negPenaltySlope * x);
const gasPenalty = (x: number) =>
  (poolGasCost * gasPrice) / (1 + Math.exp(-gasPenaltySlope * (x - gasPenaltyShift)));

const r = (x: number, a: number, b: number) => interests(x, a, b) - negPenalty(x) - gasPenalty(x);

const dInterests = (x: number, a: number, b: number) => (a * b * dt) / (b + x) ** 2;
const dNegPenalty = (x: number) => -negPenaltySlope * Math.exp(-negPenaltySlope * x);
const dGasPenalty = (x: number) =>
  -(gasPenaltySlope * poolGasCost * gasPrice * Math.exp(-gasPenaltySlope * (x - gasPenaltyShift))) /
  (1 + Math.exp(-gasPenaltySlope * (x - gasPenaltyShift))) ** 2;

const dr = (x: number, a: number, b: number) =>
  dInterests(x, a, b) - dNegPenalty(x) - dGasPenalty(x);

const {
  best: { x, fx },
  i,
} = minimize(
  ([x, y, z]) => {
    const remaining = L - (x + y + z);

    return -(r(x, a1, b1) + r(y, a2, b2) + r(z, a3, b3) + r(remaining, a4, b4));
  },
  ([x, y, z]) => {
    const remaining = L - (x + y + z);

    return [
      -(dr(x, a1, b1) - dr(remaining, a4, b4)),
      -(dr(y, a2, b2) - dr(remaining, a4, b4)),
      -(dr(z, a3, b3) - dr(remaining, a4, b4)),
    ];
  },
  [L / 4, L / 4, L / 4],
  L / 10
);

const total = x.reduce((a, tot) => a + tot);
console.log(x.concat([L - total]), total, (-fx * 100) / (L * dt), i);
