import { maximize } from "./gradient-descent";

const L = 3300;
const dt = 1; // 1 year

const pools = [
  [20, 1000],
  [30, 2000],
  [20, 2000],
  [15, 3000],
];

const dim = pools.length;

const interests = (x: number, a: number, b: number) => {
  if (Math.abs(x) >= Infinity) return a * dt - poolGasCost * gasPrice; // first-order approximation

  return (a / (b + x)) * x * dt;
};
const dInterests = (x: number, a: number, b: number) => (a * b * dt) / (b + x) ** 2;

const depositThreshold = L / 200;

const poolGasCost = 80_000; // arbitrary value
const gasPrice = 30e-9; // let's assume asset is ETH and gas price is 30 gwei

const nu = (x: number, a: number, b: number) => interests(x, a, b);
const dNu = (x: number, a: number, b: number) => dInterests(x, a, b);

const { x, i } = maximize(
  (x) =>
    x
      .map((xi, i) => {
        const [a, b] = pools[i];

        return nu(xi, a, b);
      })
      .reduce((n, tot) => n + tot),
  (x) => {
    const grad = x.map((xi, i) => {
      const [a, b] = pools[i];

      return dNu(xi, a, b) * L;
    });

    let nH2 = dim; // norm 2 of constant sum hyperplane's normal vector
    let dotH = grad.reduce((g, tot) => g + tot); // dot product of gradient and constant sum hyperplane's normal vector
    let gradH = grad.map((g) => g - dotH / nH2); // gradient projected on constant sum hyperplane

    let vH = new Array(dim).fill(1); // constant sum sub vector space's definition vector
    let extraH = 0;

    while (true) {
      let underflow = false;

      for (let i = 0; i < dim; ++i) {
        const extra = x[i] + gradH[i];

        if (extra < 0) {
          underflow = true;
          extraH += extra;
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
  },
  new Array(dim).fill(L / dim)
);

console.log(x, i);

let nH2 = dim; // norm 2 of liquidity hyperplane's normal vector
let xH = x.slice();
let vH = new Array(dim).fill(1); // constant sum sub vector space's definition vector

for (let i = 0; i < dim; ++i) {
  if (xH[i] < depositThreshold) {
    xH[i] = 0;
    vH[i] = 0;
    nH2 -= 1;
  }
}

if (nH2 <= 0) xH.fill(0);
else {
  const dotH = xH.reduce((tot, xi) => xi + tot) - L; // dot product of x and liquidity sub vector space's definition vector
  xH = xH.map((xi, i) => xi - (dotH * vH[i]) / nH2); // x projected on sub vector space
}

console.log(xH);

const totalInterests = xH.map((xi, i) => {
  const [a, b] = pools[i];

  return interests(xi, a, b);
});
const totalAccrued = totalInterests.reduce((tot, a) => a + tot);
const cost = nH2 * poolGasCost * gasPrice;

console.log(totalInterests, totalAccrued - cost, ((totalAccrued - cost) * 100) / (L * dt));
