/**
 * Minimize an unconstrained function using first order gradient descent algorithm.
 * @param {function} fnc Function to be minimized. This function takes
 * array of size N as an input, and returns a scalar value as output,
 * which is to be minimized.
 * @param {function} grd A gradient function of the objective.
 * @param {Array} x0 An array of values of size N, which is an initialization
 *  to the minimization algorithm.
 * @return {Object} An object instance with two fields: argument, which
 * denotes the best argument found thus far, and fncvalue, which is a
 * value of the function at the best found argument.
 */
export const minimize_GradientDescent = function (
  fnc: (args: number[]) => number,
  grd: (args: number[]) => number[],
  x0: number[]
) {
  // fnc: function which takes array of size N as an input
  // grd: gradient (array of size N) of function for some input
  // x0: array or real numbers of size N;
  // serves as initialization of algorithm.

  // solution is a struct, with fields:
  // argument: solution argument
  // fncvalue: function value at found optimum
  let x = x0.slice();

  let convergence = false;
  let eps = 2e-3;
  let alpha = 0.01;

  let pfx = fnc(x);
  let fx = pfx;

  while (!convergence) {
    const g = grd(x);
    convergence = absLe(g, eps);

    if (convergence) break;

    // a simple step size selection rule. Near x function acts linear
    // (this is assumed at least) and thus very small values of alpha
    // should lead to (small) improvement. Increasing alpha would
    // yield better improvement up to certain alpha size.

    let xn = x.slice();
    // addMul(xn, -alpha, g); // perform step
    // fx = fnc(xn);

    while (true) {
      addMul(xn, -alpha, g); // perform step
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

  return { x, fx };
};

/**
 * Fixed step size updating value of x.
 * @ignore
 * @param {Array} x First vector argument.
 * @param {Number} a Step size.
 * @param {Array} g Gradient.
 */
function addMul(x: number[], a: number, g: number[]) {
  for (let i = 0; i < x.length; i++) {
    x[i] = x[i] + a * g[i];
  }

  return x;
}

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
    if (Math.abs(x[i]) >= eps) {
      return false;
    }
  }
  return true;
}
