/**
 * Minimize an unconstrained function using first order gradient descent algorithm.
 * @param {function} fnc Function to be minimized. This function takes
 * array of size N as an input, and returns a scalar value as output,
 * which is to be minimized.
 * @param {function} grd A gradient function of the objective.
 * @param {Array} x0 An array of values of size N, which is an initialization
 *  to the minimization algorithm.
 * @return {Object} An object instance with two fields: x, which
 * denotes the best argument found thus far, and fx, which is a
 * value of the function at the best found argument.
 */
export const minimize = function (
  fnc: (args: number[]) => number,
  grd: (args: number[]) => number[],
  x0: number[],
  alpha = 1000,
  improvement = 1e-6
) {
  const dim = x0.length;

  let x = x0.slice();
  let fx = fnc(x);

  let pfx = fx;
  const best = { x, fx };

  while (true) {
    const g = grd(x);

    let xn = x.slice();

    for (let i = 0; i < dim; i++) xn[i] = xn[i] - alpha * g[i]; // perform step

    fx = fnc(xn);

    if (fx < pfx) {
      best.x = xn;
      best.fx = fx;
    }

    if (Math.abs(pfx - fx) < improvement || isNaN(fx) || Math.abs(fx) >= Infinity) return best;

    alpha *= 0.999;

    x = xn;
    pfx = fx;

    console.log("x", x);
    console.log("g", g);
    console.log("fx", fx);
  }
};
