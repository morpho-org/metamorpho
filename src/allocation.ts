import { maximize } from "./gradient-descent";
import { interests, dInterests, totalInterests } from "./utils";

/**
 * Routes the given total liquidity L across the given pools, so that the total interests accrued after 1 year is maximized.
 * @param L The total liquidity to allocate.
 * @param pools The pools' rates model variables.
 * @returns The liquidity allocation l and it's associated total interests accrued after 1 year.
 */
export const allocate = (L: number, pools: [number, number][]) => {
  const dim = pools.length;

  const f = (x: number[]) => totalInterests(x, pools);

  const df = (x: number[]) => {
    const grad = x.map((xi, i) => dInterests(xi, pools[i]) * L);

    // The gradient doesn't necessarily leads to a valid vector subspace (with regard to our contrained problem: xi >= 0 && x1 + ... + xn == L)
    // So we define H the constant sum vector subspace, initially the hyperplane x1 + ... + xn == L (which we call the liquidity hyperplane)
    // And iteratively project the gradient onto this subspace, so that x always stay in a valid subspace (given x0 was in a valid subspace).
    // At each step, if the gradient points to a boundary of the subspace along a dimension i, the gradient is capped so that xi == 0 at next gradient descent step
    // and that the gradient does point to a valid subspace. If it doesn't, the process is repeated until it does OR the gradient is zero.

    let nH2 = dim; // norm 2 of constant sum vector subspace
    let vH = new Array(dim).fill(1); // constant sum subspace's definition vector
    let dotH = grad.reduce((g, tot) => g + tot); // dot product of gradient and constant sum subspace's definition vector
    let gradH = grad.map((g) => g - dotH / nH2); // gradient projected on constant sum subspace

    let extraH = 0;

    while (true) {
      let underflow = false;

      for (let i = 0; i < dim; ++i) {
        const extra = x[i] + gradH[i];

        if (extra < 0) {
          underflow = true;
          extraH += extra; // the portion of the gradient capped along this dimension is kept projected onto remaining dimensions at the end
          gradH[i] = -x[i];
          vH[i] = 0;
          nH2 -= 1;
        }
      }

      if (!underflow) break;

      if (nH2 <= 0) return gradH.fill(0);

      dotH = gradH.reduce((tot, g, i) => g * vH[i] + tot); // dot product of gradient and sub vector space's definition vector
      gradH = gradH.map((g, i) => g - (dotH * vH[i]) / nH2); // gradient projected on sub vector space
    }

    if (extraH > 0) gradH = gradH.map((g, i) => g - (extraH * vH[i]) / nH2); // extra added to gradient projection

    return gradH;
  };

  const { x, fx, i } = maximize(f, df, new Array(dim).fill(L / dim));

  return { allocation: x, interests: fx, steps: i };
};

/**
 * Redistributes the given liquidity allocation so that liquidity is grouped back,
 * making sure that interests generated from a pool is always worth the cost of supplying to the pool.
 * @param x The liquidity allocation.
 * @param pools The pools' rates model variables.
 * @returns The not necessarily optimal, canonical liquidity re-allocation.
 */
export const narrow = (x: number[], pools: [number, number][], poolCost: number) => {
  const dim = x.length;
  const L = x.reduce((tot, xi) => tot + xi);

  let nH2 = dim; // norm 2 of constant sum vector subspace
  let vH = new Array(dim).fill(1); // constant sum subspace's definition vector
  let xH = x.slice();

  for (let i = 0; i < dim; ++i) {
    if (interests(xH[i], pools[i]) < poolCost) {
      xH[i] = 0;
      vH[i] = 0;
      nH2 -= 1;
    }
  }

  if (nH2 <= 0) return xH.fill(0);

  const dotH = xH.reduce((tot, xi) => xi + tot) - L; // dot product of x and subspace's definition vector

  return xH.map((xi, i) => xi - (dotH * vH[i]) / nH2); // x projected on subspace
};
