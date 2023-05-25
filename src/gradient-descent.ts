/**
 * Minimize an unconstrained function using first order gradient descent algorithm.
 * @param {function} fnc Function to be minimized. This function takes
 * array of size N as an input, and returns a scalar value as output,
 * which is to be minimized.
 * @param {function} grd A gradient function of the objective.
 * @param {Array} x0 An array of values of size N, which is an initialization
 *  to the minimization algorithm.
 * @param {number} alpha The gradient factor.
 * @param {number} multiplier The factor to multiply alpha by at each step. Values closer to 1 may converge slower but closer to a minima.
 * @param {number} improvement The minimum improvement in objective between 2 steps to keep searching.
 * @return {Object} An object instance with two fields: x, which
 * denotes the best argument found, and i, which represents the number of loops performed.
 */
export const minimize = function (
  fnc: (args: number[]) => number,
  grd: (args: number[]) => number[],
  x0: number[],
  alpha = 1,
  multiplier = 0.9999,
  improvement = 1e-6
) {
  const dim = x0.length;

  let x = x0;
  let fx = fnc(x);

  let pfx = fx;
  let best = x;

  let i = 0;
  for (; i < 25_000; ++i) {
    const g = grd(x);

    let xn = x.slice();

    for (let j = 0; j < dim; j++) xn[j] = xn[j] - alpha * g[j]; // perform step

    fx = fnc(xn);

    if (fx < pfx) best = xn;

    if (Math.abs(pfx - fx) < improvement || isNaN(fx) || Math.abs(fx) >= Infinity) break;

    alpha *= multiplier;

    x = xn;
    pfx = fx;
  }

  return { x: best, i };
};
