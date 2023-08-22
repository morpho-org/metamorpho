// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "contracts/bundlers/EVMBundler.sol";

import {ErrorsLib as BulkerErrorsLib} from "contracts/bundlers/libraries/ErrorsLib.sol";

import "./BaseBundlerTest.sol";

contract EVMBundlerTest is BaseBundlerTest {
    using MorphoLib for IMorpho;
    using MathLib for uint256;
    using SharesMathLib for uint256;

    EVMBundler private bundler;

    function setUp() public override {
        super.setUp();

        bundler = new EVMBundler(address(morpho));

        vm.startPrank(USER);
        borrowableToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);
        borrowableToken.approve(address(bundler), type(uint256).max);
        collateralToken.approve(address(bundler), type(uint256).max);
        morpho.setAuthorization(address(bundler), true);
        // So tests can borrow/withdraw on behalf of USER without pranking it.
        morpho.setAuthorization(address(this), true);
        vm.stopPrank();
    }

    /* INVARIANTS */

    function invariantBundlerBalanceOfZero() public {
        assertEq(collateralToken.balanceOf(address(bundler)), 0, "collateral.balanceOf(bundler)");
        assertEq(borrowableToken.balanceOf(address(bundler)), 0, "borrowable.balanceOf(bundler)");
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

        zeroAddressData[0] = abi.encodeCall(ERC20Bundler.transfer, (address(borrowableToken), address(0), amount));
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

        transferData[0] = abi.encodeCall(ERC20Bundler.transfer, (address(borrowableToken), receiver, 0));
        transferFromData[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableToken), 0));
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

        supplyData[0] = abi.encodeCall(MorphoBundler.morphoSupply, (marketParams, amount, 0, address(bundler), hex""));
        supplyCollateralData[0] =
            abi.encodeCall(MorphoBundler.morphoSupplyCollateral, (marketParams, amount, address(bundler), hex""));
        repayData[0] = abi.encodeCall(MorphoBundler.morphoRepay, (marketParams, amount, 0, address(bundler), hex""));

        vm.expectRevert(bytes(BulkerErrorsLib.BUNDLER_ADDRESS));
        bundler.multicall(block.timestamp, supplyData);
        vm.expectRevert(bytes(BulkerErrorsLib.BUNDLER_ADDRESS));
        bundler.multicall(block.timestamp, supplyCollateralData);
        vm.expectRevert(bytes(BulkerErrorsLib.BUNDLER_ADDRESS));
        bundler.multicall(block.timestamp, repayData);
    }

    function testSupply(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory data = new bytes[](2);

        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableToken), amount));
        data[1] = abi.encodeCall(MorphoBundler.morphoSupply, (marketParams, amount, 0, USER, hex""));

        borrowableToken.setBalance(USER, amount);
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        assertEq(borrowableToken.balanceOf(USER), 0, "borrowable.balanceOf(USER)");
        assertEq(borrowableToken.balanceOf(address(bundler)), 0, "borrowable.balanceOf(address(bundler))");
        assertEq(borrowableToken.balanceOf(address(morpho)), amount, "borrowable.balanceOf(address(morpho))");

        assertEq(morpho.collateral(id, USER), 0, "collateral(USER)");
        assertEq(morpho.supplyShares(id, USER), amount.toSharesDown(0,0), "supplyShares(USER)");
        assertEq(morpho.borrowShares(id, USER), 0, "borrowShares(USER)");
    }

    function testSupplyCollateral(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory data = new bytes[](2);

        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(collateralToken), amount));
        data[1] = abi.encodeCall(MorphoBundler.morphoSupplyCollateral, (marketParams, amount, USER, hex""));

        collateralToken.setBalance(USER, amount);
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        assertEq(collateralToken.balanceOf(USER), 0, "borrowable.balanceOf(USER)");
        assertEq(collateralToken.balanceOf(address(bundler)), 0, "borrowable.balanceOf(address(bundler))");
        assertEq(collateralToken.balanceOf(address(morpho)), amount, "borrowable.balanceOf(address(morpho))");

        assertEq(morpho.collateral(id, USER), amount, "collateral(USER)");
        assertEq(morpho.supplyShares(id, USER), 0, "supplyShares(USER)");
        assertEq(morpho.borrowShares(id, USER), 0, "borrowShares(USER)");
    }

    function testWithdraw(uint256 amount, uint256 withdrawnShares) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        uint256 expectedSupplyShares = amount.toSharesDown(0,0);
        withdrawnShares = bound(withdrawnShares, 1, expectedSupplyShares);
        uint256 expectedWithdrawnAmount = withdrawnShares.toAssetsDown(amount, expectedSupplyShares);

        bytes[] memory data = new bytes[](1);

        data[0] = abi.encodeCall(MorphoBundler.morphoWithdraw, (marketParams, 0, withdrawnShares, USER));

        borrowableToken.setBalance(USER, amount);
        vm.startPrank(USER);

        morpho.supply(marketParams, amount, 0, USER, hex"");
        bundler.multicall(block.timestamp, data);
        vm.stopPrank();

        assertEq(borrowableToken.balanceOf(USER), expectedWithdrawnAmount, "borrowable.balanceOf(USER)");
        assertEq(borrowableToken.balanceOf(address(bundler)), 0, "borrowable.balanceOf(address(bundler))");
        assertEq(borrowableToken.balanceOf(address(morpho)), amount - expectedWithdrawnAmount, "borrowable.balanceOf(address(morpho))");

        assertEq(morpho.collateral(id, USER), 0, "collateral(USER)");
        assertEq(morpho.supplyShares(id, USER), expectedSupplyShares - withdrawnShares, "supplyShares(USER)");
        assertEq(morpho.borrowShares(id, USER), 0, "borrowShares(USER)");
    }

    function _testSupplyCollateralBorrow(uint256 amount, uint256 collateralAmount, address receiver) internal {
        assertEq(collateralToken.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        assertEq(borrowableToken.balanceOf(USER), 0, "borrowable.balanceOf(USER)");

        assertEq(collateralToken.balanceOf(receiver), 0, "collateral.balanceOf(receiver)");
        assertEq(borrowableToken.balanceOf(receiver), amount, "borrowable.balanceOf(receiver)");

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

        borrowableToken.setBalance(address(this), amount);
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(collateralToken), collateralAmount));
        data[1] = abi.encodeCall(MorphoBundler.morphoSupplyCollateral, (marketParams, collateralAmount, USER, hex""));
        data[2] = abi.encodeCall(MorphoBundler.morphoBorrow, (marketParams, amount, 0, receiver));

        collateralToken.setBalance(USER, collateralAmount);

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        _testSupplyCollateralBorrow(amount, collateralAmount, receiver);
    }

    function testSupplyCollateralBorrowViaCallback(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(morpho));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        borrowableToken.setBalance(address(this), amount);
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        bytes[] memory callbackData = new bytes[](2);
        callbackData[0] = abi.encodeCall(MorphoBundler.morphoBorrow, (marketParams, amount, 0, receiver));
        callbackData[1] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(collateralToken), collateralAmount));

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(
            MorphoBundler.morphoSupplyCollateral, (marketParams, collateralAmount, USER, abi.encode(callbackData))
        );

        collateralToken.setBalance(USER, collateralAmount);

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        _testSupplyCollateralBorrow(amount, collateralAmount, receiver);
    }

    function _testRepayWithdrawCollateral(uint256 collateralAmount, address receiver) internal {
        assertEq(collateralToken.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        assertEq(borrowableToken.balanceOf(USER), 0, "borrowable.balanceOf(USER)");

        assertEq(collateralToken.balanceOf(receiver), collateralAmount, "collateral.balanceOf(receiver)");
        assertEq(borrowableToken.balanceOf(receiver), 0, "borrowable.balanceOf(receiver)");

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

        borrowableToken.setBalance(address(this), amount);
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        collateralToken.setBalance(address(this), collateralAmount);
        morpho.supplyCollateral(marketParams, collateralAmount, USER, hex"");
        morpho.borrow(marketParams, amount, 0, USER, USER);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableToken), amount));
        data[1] = abi.encodeCall(MorphoBundler.morphoRepay, (marketParams, amount, 0, USER, hex""));
        data[2] = abi.encodeCall(MorphoBundler.morphoWithdrawCollateral, (marketParams, collateralAmount, receiver));

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        _testRepayWithdrawCollateral(collateralAmount, receiver);
    }

    function testRepayWithdrawCollateralViaCallback(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(morpho));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        borrowableToken.setBalance(address(this), amount);
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        collateralToken.setBalance(address(this), collateralAmount);
        morpho.supplyCollateral(marketParams, collateralAmount, USER, hex"");
        morpho.borrow(marketParams, amount, 0, USER, USER);

        bytes[] memory callbackData = new bytes[](2);
        callbackData[0] =
            abi.encodeCall(MorphoBundler.morphoWithdrawCollateral, (marketParams, collateralAmount, receiver));
        callbackData[1] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableToken), amount));

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(MorphoBundler.morphoRepay, (marketParams, amount, 0, USER, abi.encode(callbackData)));

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        _testRepayWithdrawCollateral(collateralAmount, receiver);
    }
}
