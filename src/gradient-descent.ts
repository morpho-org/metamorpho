export const maximize = function (
  fnc: (args: number[]) => number,
  grd: (args: number[]) => number[],
  x0: number[],
  improvement = 1e-8
) {
  const dim = x0.length;

  let x = x0;
  let fx = fnc(x);

  let pfx = fx;
  let best = x;

  let i = 0;
  for (; i < 10_000; ++i) {
    const g = grd(x);
    console.log("g", g);

    let xn = x.slice();

    for (let j = 0; j < dim; j++) xn[j] = xn[j] + g[j]; // perform step

    console.log("x", xn);

    fx = fnc(xn);

    console.log("fx", fx);

    if (fx > pfx) best = xn;

    console.log("|pfx-fx|", Math.abs(pfx - fx));

    if (Math.abs(pfx - fx) < improvement || isNaN(fx) || Math.abs(fx) >= Infinity) break;

    x = xn;
    pfx = fx;
  }

  return { x: best, i };
};
