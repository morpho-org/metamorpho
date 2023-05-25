import { minimize } from "./gradient-descent";

const L = 10;
const dt = 1; // 1 year

const penaltySlope = 1e5;

const [a1, b1] = [20, 1000];
const [a2, b2] = [30, 2000];
const [a3, b3] = [20, 1500];
const [a4, b4] = [15, 3000];

const r = (x: number, a: number, b: number) => (a / (b + x)) * x * dt - Math.exp(-penaltySlope * x);

const dr = (x: number, remaining: number, a: number, b: number) => {
  return (
    ((a * b) / (b + x) ** 2 - (a4 * b4) / (b4 + remaining) ** 2) * dt +
    penaltySlope * (Math.exp(-penaltySlope * x) - Math.exp(-penaltySlope * remaining))
  );
};

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

    return [-dr(x, remaining, a1, b1), -dr(x, remaining, a2, b2), -dr(x, remaining, a3, b3)];
  },
  [L / 4, L / 4, L / 4],
  L / 10
);

const total = x.reduce((a, tot) => a + tot);
console.log(x.concat([L - total]), total, (-fx * 100) / (L * dt), i);
