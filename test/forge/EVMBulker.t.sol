// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "contracts/bulkers/EVMBulker.sol";

import "./BaseBulkerTest.sol";

contract EVMBulkerTest is BaseBulkerTest {
    using FixedPointMathLib for uint256;

    EVMBulker private bulker;

    function setUp() public override {
        super.setUp();

        bulker = new EVMBulker(address(blue));

        vm.startPrank(USER);
        borrowableAsset.approve(address(bulker), type(uint256).max);
        collateralAsset.approve(address(bulker), type(uint256).max);
        blue.setAuthorization(address(bulker), true);
        vm.stopPrank();
    }

    function testSupplyCollateralBorrow(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(blue));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        borrowableAsset.setBalance(address(this), amount);
        blue.supply(market, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(ERC20Bulker.transferFrom2, (address(collateralAsset), collateralAmount));
        data[1] = abi.encodeCall(BlueBulker.blueSupplyCollateral, (market, collateralAmount, USER, hex""));
        data[2] = abi.encodeCall(BlueBulker.blueBorrow, (market, amount, 0, receiver));

        collateralAsset.setBalance(USER, collateralAmount);

        vm.prank(USER);
        bulker.multicall(block.timestamp, data);

        assertEq(collateralAsset.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        assertEq(borrowableAsset.balanceOf(USER), 0, "borrowable.balanceOf(USER)");

        assertEq(collateralAsset.balanceOf(receiver), 0, "collateral.balanceOf(receiver)");
        assertEq(borrowableAsset.balanceOf(receiver), amount, "borrowable.balanceOf(receiver)");

        assertEq(collateralAsset.balanceOf(address(bulker)), 0, "collateral.balanceOf(bulker)");
        assertEq(borrowableAsset.balanceOf(address(bulker)), 0, "borrowable.balanceOf(bulker)");

        assertEq(blue.collateral(id, address(bulker)), 0, "collateral(bulker)");
        assertEq(blue.supplyShares(id, address(bulker)), 0, "supplyShares(bulker)");
        assertEq(blue.borrowShares(id, address(bulker)), 0, "borrowShares(bulker)");

        assertEq(blue.collateral(id, USER), collateralAmount, "collateral(USER)");
        assertEq(blue.supplyShares(id, USER), 0, "supplyShares(USER)");
        assertEq(blue.borrowShares(id, USER), amount * SharesMathLib.VIRTUAL_SHARES, "borrowShares(USER)");

        if (receiver != USER) {
            assertEq(blue.collateral(id, receiver), 0, "collateral(receiver)");
            assertEq(blue.supplyShares(id, receiver), 0, "supplyShares(receiver)");
            assertEq(blue.borrowShares(id, receiver), 0, "borrowShares(receiver)");
        }
    }
}
