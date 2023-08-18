// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "contracts/bundlers/EVMBundler.sol";

import {ErrorsLib as BulkerErrorsLib} from "contracts/bundlers/libraries/ErrorsLib.sol";

import "./BaseBundlerTest.sol";

contract EVMBundlerTest is BaseBundlerTest {
    using FixedPointMathLib for uint256;

    EVMBundler private bundler;

    function setUp() public override {
        super.setUp();

        bundler = new EVMBundler(address(morpho));

        vm.startPrank(USER);
        borrowableAsset.approve(address(bundler), type(uint256).max);
        collateralAsset.approve(address(bundler), type(uint256).max);
        morpho.setAuthorization(address(bundler), true);
        morpho.setAuthorization(address(this), true); // So tests can borrow/withdraw on behalf of USER without pranking it.
        vm.stopPrank();
    }

    /* INVARIANTS */

    function invariantBundlerBalanceOfZero() public {
        assertEq(collateralAsset.balanceOf(address(bundler)), 0, "collateral.balanceOf(bundler)");
        assertEq(borrowableAsset.balanceOf(address(bundler)), 0, "borrowable.balanceOf(bundler)");
    }

    function invariantBundlerPositionZero() public {
        assertEq(morpho.collateral(id, address(bundler)), 0, "collateral(bundler)");
        assertEq(morpho.supplyShares(id, address(bundler)), 0, "supplyShares(bundler)");
        assertEq(morpho.borrowShares(id, address(bundler)), 0, "borrowShares(bundler)");
    }

    /* TESTS */

    function testTranferInvalidAddresses(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory zeroAddressData = new bytes[](1);
        bytes[] memory bundlerAddressData = new bytes[](1);

        zeroAddressData[0] = abi.encodeCall(ERC20Bundler.transfer, (address(borrowableAsset), address(0), amount));
        bundlerAddressData[0] = abi.encodeCall(ERC20Bundler.transfer, (address(bundler), address(0), amount));

        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
        bundler.multicall(block.timestamp, zeroAddressData);
        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
        bundler.multicall(block.timestamp, bundlerAddressData);
    }

    function testTranferZeroAmount(address receiver, Signature calldata signature) public {
        vm.assume(receiver != address(0) && receiver != address(bundler));

        bytes[] memory transferData = new bytes[](1);
        bytes[] memory transferFromData = new bytes[](1);
        bytes[] memory approve2Data = new bytes[](1);

        transferData[0] = abi.encodeCall(ERC20Bundler.transfer, (address(borrowableAsset), receiver, 0));
        transferFromData[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (receiver, 0));
        approve2Data[0] = abi.encodeCall(ERC20Bundler.approve2, (receiver, 0, block.timestamp, signature));

        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_AMOUNT));
        bundler.multicall(block.timestamp, transferData);
        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_AMOUNT));
        bundler.multicall(block.timestamp, transferFromData);
        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_AMOUNT));
        bundler.multicall(block.timestamp, approve2Data);
    }

    function testBundlerAddress(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory supplyData = new bytes[](1);
        bytes[] memory supplyCollateralData = new bytes[](1);
        bytes[] memory repayData = new bytes[](1);

        supplyData[0] = abi.encodeCall(MorphoBundler.morphoSupply, (market, amount, 0, address(bundler), hex""));
        supplyCollateralData[0] = abi.encodeCall(MorphoBundler.morphoSupplyCollateral, (market, amount, address(bundler), hex""));
        repayData[0] = abi.encodeCall(MorphoBundler.morphoRepay, (market, amount, 0, address(bundler), hex""));

        vm.expectRevert(bytes(BulkerErrorsLib.BUNDLER_ADDRESS));
        bundler.multicall(block.timestamp, supplyData);
        vm.expectRevert(bytes(BulkerErrorsLib.BUNDLER_ADDRESS));
        bundler.multicall(block.timestamp, supplyCollateralData);
        vm.expectRevert(bytes(BulkerErrorsLib.BUNDLER_ADDRESS));
        bundler.multicall(block.timestamp, repayData);
    }

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
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(collateralAsset), collateralAmount));
        data[1] = abi.encodeCall(MorphoBundler.morphoSupplyCollateral, (market, collateralAmount, USER, hex""));
        data[2] = abi.encodeCall(MorphoBundler.morphoBorrow, (market, amount, 0, receiver));

        collateralAsset.setBalance(USER, collateralAmount);

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

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
        callbackData[0] = abi.encodeCall(MorphoBundler.morphoBorrow, (market, amount, 0, receiver));
        callbackData[1] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(collateralAsset), collateralAmount));

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(
            MorphoBundler.morphoSupplyCollateral, (market, collateralAmount, USER, abi.encode(callbackData))
        );

        collateralAsset.setBalance(USER, collateralAmount);

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

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
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableAsset), amount));
        data[1] = abi.encodeCall(MorphoBundler.morphoRepay, (market, amount, 0, USER, hex""));
        data[2] = abi.encodeCall(MorphoBundler.morphoWithdrawCollateral, (market, collateralAmount, receiver));

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

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
        callbackData[0] = abi.encodeCall(MorphoBundler.morphoWithdrawCollateral, (market, collateralAmount, receiver));
        callbackData[1] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableAsset), amount));

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(MorphoBundler.morphoRepay, (market, amount, 0, USER, abi.encode(callbackData)));

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        _testRepayWithdrawCollateral(collateralAmount, receiver);
    }
}
