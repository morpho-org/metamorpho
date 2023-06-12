/**
 * Calculates the interests accrued over the duration dt, having supplied x to the given pool.
 * @param x The liquidity hypothetically supplied.
 * @param pool The pool's rate model variables.
 * @param dt The supply duration.
 * @returns The interests accrued over the supply duration.
 */
export const interests = (x: number, pool: [number, number], dt = 1) => {
  const [a, b] = pool;
  if (Math.abs(x) >= Infinity) return a * dt; // first-order approximation

  return ((a * dt) / (b + x)) * x;
};

export const dInterests = (x: number, pool: [number, number]) => {
  const [a, b] = pool;

  return (a * b) / (b + x) ** 2;
};

export const totalInterests = (x: number[], pools: [number, number][]) =>
  x.reduce((tot, xi, i) => tot + interests(xi, pools[i]));

export const profit = (x: number, pool: [number, number], poolCost: number, dt = 1) =>
  interests(x, pool, dt) - poolCost;

export const totalProfit = (x: number[], pools: [number, number][], poolCost: number, dt = 1) =>
  x.reduce((tot, xi, i) => tot + profit(xi, pools[i], poolCost, dt));
