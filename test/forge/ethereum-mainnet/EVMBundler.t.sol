// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "contracts/bundlers/EVMBundler.sol";

import "../helpers/ForkTest.sol";

contract EVMBundlerEthereumTest is ForkTest {
    using FixedPointMathLib for uint256;

    EVMBundler private bundler;

    function _network() internal pure override returns (string memory) {
        return "ethereum-mainnet";
    }

    function setUp() public override {
        super.setUp();

        bundler = new EVMBundler(address(morpho));

        vm.startPrank(USER);
        morpho.setAuthorization(address(bundler), true);
        morpho.setAuthorization(address(this), true); // So tests can borrow/withdraw on behalf of USER without pranking it.
        vm.stopPrank();
    }

    /* INVARIANTS */

    function invariantBundlerBalanceOfZero() public {
        // assertEq(collateralAsset.balanceOf(address(bundler)), 0, "collateral.balanceOf(bundler)");
        // assertEq(borrowableAsset.balanceOf(address(bundler)), 0, "borrowable.balanceOf(bundler)");
    }

    function invariantBundlerPositionZero() public {
        // assertEq(morpho.collateral(id, address(bundler)), 0, "collateral(bundler)");
        // assertEq(morpho.supplyShares(id, address(bundler)), 0, "supplyShares(bundler)");
        // assertEq(morpho.borrowShares(id, address(bundler)), 0, "borrowShares(bundler)");
    }

    /* TESTS */

    function testSupply(uint256 amount, address onBehalf) public {
        vm.assume(onBehalf != address(0));
        vm.assume(onBehalf != address(morpho));
        vm.assume(onBehalf != address(bundler));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        // bytes[] memory data = new bytes[](2);
        // data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableAsset), amount));
        // data[1] = abi.encodeCall(MorphoBundler.morphoSupply, (market, amount, 0, onBehalf, hex""));

        // borrowableAsset.setBalance(USER, amount);

        // vm.prank(USER);
        // bundler.multicall(block.timestamp, data);

        // assertEq(collateralAsset.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        // assertEq(borrowableAsset.balanceOf(USER), 0, "borrowable.balanceOf(USER)");

        // assertEq(collateralAsset.balanceOf(onBehalf), 0, "collateral.balanceOf(onBehalf)");
        // assertEq(borrowableAsset.balanceOf(onBehalf), 0, "borrowable.balanceOf(onBehalf)");

        // assertEq(morpho.collateral(id, onBehalf), 0, "collateral(onBehalf)");
        // assertEq(morpho.supplyShares(id, onBehalf), amount * SharesMathLib.VIRTUAL_SHARES, "supplyShares(onBehalf)");
        // assertEq(morpho.borrowShares(id, onBehalf), 0, "borrowShares(onBehalf)");

        // if (onBehalf != USER) {
        //     assertEq(morpho.collateral(id, USER), 0, "collateral(USER)");
        //     assertEq(morpho.supplyShares(id, USER), 0, "supplyShares(USER)");
        //     assertEq(morpho.borrowShares(id, USER), 0, "borrowShares(USER)");
        // }
    }
}
