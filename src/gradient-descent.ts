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
  eps = 2e-3,
  alpha = 0.01
) {
  const dim = x0.length;
  let x = x0.slice();
  let pfx = fnc(x);
  let fx = pfx;

  while (true) {
    const g = grd(x);

    if (absLe(g, eps)) return { x, fx };

    // a simple step size selection rule. Near x function acts linear
    // (this is assumed at least) and thus very small values of alpha
    // should lead to (small) improvement. Increasing alpha would
    // yield better improvement up to certain alpha size.

    let xn = x.slice();

    while (true) {
      for (let i = 0; i < dim; i++) xn[i] = xn[i] - alpha * g[i]; // perform step

      fx = fnc(xn);

      if (pfx >= fx) {
        alpha *= 1.1;
        break;
      }

      alpha *= 0.7;

      xn = x.slice();
    }

    x = xn;
    pfx = fx;
  }
};

/**
 * Checks whether absolute values in a vector are greater than
 * some threshold.
 * @ignore
 * @param {Array} x Vector that is checked.
 * @param {Number} eps Threshold.
 */
function absLe(x: number[], eps: number) {
  // this procedure is used for stopping criterion check
  for (let i = 0; i < x.length; i++) {
    if (Math.abs(x[i]) >= eps) return false;
  }

  return true;
}
