// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "contracts/bulkers/EVMBulker.sol";

import "./BaseBulkerTest.sol";

contract EVMBulkerTest is BaseBulkerTest {
    using FixedPointMathLib for uint256;

    EVMBulker private bulker;

    function setUp() public override {
        super.setUp();

        bulker = new EVMBulker(address(morpho));

        vm.startPrank(USER);
        borrowableAsset.approve(address(bulker), type(uint256).max);
        collateralAsset.approve(address(bulker), type(uint256).max);
        morpho.setAuthorization(address(bulker), true);
        morpho.setAuthorization(address(this), true); // So tests can borrow/withdraw on behalf of USER without pranking it.
        vm.stopPrank();
    }

    /* INVARIANTS */

    function invariantBulkerBalanceOfZero() public {
        assertEq(collateralAsset.balanceOf(address(bulker)), 0, "collateral.balanceOf(bulker)");
        assertEq(borrowableAsset.balanceOf(address(bulker)), 0, "borrowable.balanceOf(bulker)");
    }

    function invariantBulkerPositionZero() public {
        assertEq(morpho.collateral(id, address(bulker)), 0, "collateral(bulker)");
        assertEq(morpho.supplyShares(id, address(bulker)), 0, "supplyShares(bulker)");
        assertEq(morpho.borrowShares(id, address(bulker)), 0, "borrowShares(bulker)");
    }

    /* TESTS */

    function _testSupplyCollateralBorrow(uint256 amount, uint256 collateralAmount, address receiver) internal {
        assertEq(collateralAsset.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        assertEq(borrowableAsset.balanceOf(USER), 0, "borrowable.balanceOf(USER)");

        assertEq(collateralAsset.balanceOf(receiver), 0, "collateral.balanceOf(receiver)");
        assertEq(borrowableAsset.balanceOf(receiver), amount, "borrowable.balanceOf(receiver)");

        assertEq(morpho.collateral(id, USER), collateralAmount, "collateral(USER)");
        assertEq(morpho.supplyShares(id, USER), 0, "supplyShares(USER)");
        assertEq(morpho.borrowShares(id, USER), amount * SharesMathLib.VIRTUAL_SHARES, "borrowShares(USER)");

        if (receiver != USER) {
            assertEq(morpho.collateral(id, receiver), 0, "collateral(receiver)");
            assertEq(morpho.supplyShares(id, receiver), 0, "supplyShares(receiver)");
            assertEq(morpho.borrowShares(id, receiver), 0, "borrowShares(receiver)");
        }
    }

    function testSupplyCollateralBorrow(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(morpho));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        borrowableAsset.setBalance(address(this), amount);
        morpho.supply(market, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(ERC20Bulker.transferFrom2, (address(collateralAsset), collateralAmount));
        data[1] = abi.encodeCall(MorphoBulker.morphoSupplyCollateral, (market, collateralAmount, USER, hex""));
        data[2] = abi.encodeCall(MorphoBulker.morphoBorrow, (market, amount, 0, receiver));

        collateralAsset.setBalance(USER, collateralAmount);

        vm.prank(USER);
        bulker.multicall(block.timestamp, data);

        _testSupplyCollateralBorrow(amount, collateralAmount, receiver);
    }

    function testSupplyCollateralBorrowViaCallback(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(morpho));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        borrowableAsset.setBalance(address(this), amount);
        morpho.supply(market, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        bytes[] memory callbackData = new bytes[](2);
        callbackData[0] = abi.encodeCall(MorphoBulker.morphoBorrow, (market, amount, 0, receiver));
        callbackData[1] = abi.encodeCall(ERC20Bulker.transferFrom2, (address(collateralAsset), collateralAmount));

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(
            MorphoBulker.morphoSupplyCollateral, (market, collateralAmount, USER, abi.encode(callbackData))
        );

        collateralAsset.setBalance(USER, collateralAmount);

        vm.prank(USER);
        bulker.multicall(block.timestamp, data);

        _testSupplyCollateralBorrow(amount, collateralAmount, receiver);
    }

    function _testRepayWithdrawCollateral(uint256 collateralAmount, address receiver) internal {
        assertEq(collateralAsset.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        assertEq(borrowableAsset.balanceOf(USER), 0, "borrowable.balanceOf(USER)");

        assertEq(collateralAsset.balanceOf(receiver), collateralAmount, "collateral.balanceOf(receiver)");
        assertEq(borrowableAsset.balanceOf(receiver), 0, "borrowable.balanceOf(receiver)");

        assertEq(morpho.collateral(id, USER), 0, "collateral(USER)");
        assertEq(morpho.supplyShares(id, USER), 0, "supplyShares(USER)");
        assertEq(morpho.borrowShares(id, USER), 0, "borrowShares(USER)");

        if (receiver != USER) {
            assertEq(morpho.collateral(id, receiver), 0, "collateral(receiver)");
            assertEq(morpho.supplyShares(id, receiver), 0, "supplyShares(receiver)");
            assertEq(morpho.borrowShares(id, receiver), 0, "borrowShares(receiver)");
        }
    }

    function testRepayWithdrawCollateral(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(morpho));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        borrowableAsset.setBalance(address(this), amount);
        morpho.supply(market, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        collateralAsset.setBalance(address(this), collateralAmount);
        morpho.supplyCollateral(market, collateralAmount, USER, hex"");
        morpho.borrow(market, amount, 0, USER, USER);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(ERC20Bulker.transferFrom2, (address(borrowableAsset), amount));
        data[1] = abi.encodeCall(MorphoBulker.morphoRepay, (market, amount, 0, USER, hex""));
        data[2] = abi.encodeCall(MorphoBulker.morphoWithdrawCollateral, (market, collateralAmount, receiver));

        vm.prank(USER);
        bulker.multicall(block.timestamp, data);

        _testRepayWithdrawCollateral(collateralAmount, receiver);
    }

    function testRepayWithdrawCollateralViaCallback(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(morpho));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        borrowableAsset.setBalance(address(this), amount);
        morpho.supply(market, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        collateralAsset.setBalance(address(this), collateralAmount);
        morpho.supplyCollateral(market, collateralAmount, USER, hex"");
        morpho.borrow(market, amount, 0, USER, USER);

        bytes[] memory callbackData = new bytes[](2);
        callbackData[0] = abi.encodeCall(MorphoBulker.morphoWithdrawCollateral, (market, collateralAmount, receiver));
        callbackData[1] = abi.encodeCall(ERC20Bulker.transferFrom2, (address(borrowableAsset), amount));

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(MorphoBulker.morphoRepay, (market, amount, 0, USER, abi.encode(callbackData)));

        vm.prank(USER);
        bulker.multicall(block.timestamp, data);

        _testRepayWithdrawCollateral(collateralAmount, receiver);
    }
}
