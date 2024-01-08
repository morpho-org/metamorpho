// SPDX-License-Identifier: GPL-2.0-or-later
using ERC20Standard as Token;

methods {
    function asset() external returns (address) envfree;
    function MORPHO() external returns (address) envfree;

    function Token.balanceOf(address) external returns (uint256) envfree;
}

rule depositTokenChange(env e, uint256 assets, address receiver) {
    address asset = asset();
    address morpho = MORPHO();

    uint256 balanceMorphoBefore = Token.balanceOf(morpho);
    deposit(e, assets, receiver);
    uint256 balanceMorphoAfter = Token.balanceOf(morpho);

    assert assets == assert_uint256(balanceMorphoAfter - balanceMorphoBefore);
}

rule withdrawTokenChange() {
    assert true;
}
