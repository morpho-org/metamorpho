import { maximize } from "./gradient-descent";

const L = 1;
const dt = 1; // 1 year

const pools = [
  [20, 1000],
  [30, 2000],
  [20, 2000],
  [15, 3000],
];

const dim = pools.length;

const interests = (x: number, a: number, b: number) => (a / (b + x)) * x * dt;
const dInterests = (x: number, a: number, b: number) => (a * b * dt) / (b + x) ** 2;

const nu = (x: number, a: number, b: number) => {
  if (Math.abs(x) >= Infinity) return 1; // first-order approximation

  return interests(x, a, b);
};

const dNu = (x: number, a: number, b: number) => {
  if (Math.abs(x) >= Infinity) return 0; // first-order approximation

  return dInterests(x, a, b);
};

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

    let nH2 = dim; // norm 2 of liquidity hyperplane's normal vector
    let dotH = grad.reduce((g, tot) => g + tot); // dot product of gradient and liquidity hyperplane's normal vector
    let gradH = grad.map((g) => g - dotH / nH2); // gradient projected on liquidity hyperplane

    let vH = new Array(dim).fill(1); // constraint sub vector space's definition vector
    for (let i = 0; i < dim; ++i) {
      console.log("underflow", x[i], gradH[i], x[i] + gradH[i]);
      if (x[i] + gradH[i] < 0) {
        gradH[i] = 0; // TODO: prevents converging to 0 ; need to find a way to clip it to zero
        vH[i] = 0;
        nH2 -= 1;
      }
    }

    dotH = gradH.reduce((g, tot) => g + tot); // dot product of gradient and sub vector space's definition vector
    gradH = gradH.map((g, i) => g - (dotH * vH[i]) / nH2); // gradient projected on sub vector space

    // TODO: xn can still be < 0 because projected gradient on sub vector space may be too large

    return gradH;
  },
  new Array(dim).fill(L / dim)
);

console.log(x, i);

const totalInterests = x.map((xi, i) => {
  const [a, b] = pools[i];

  return interests(xi, a, b);
});
const totalAccrued = totalInterests.reduce((a, tot) => a + tot);

console.log(totalInterests, totalAccrued, (totalAccrued * 100) / (L * dt));
