// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SigUtils} from "test/forge/helpers/SigUtils.sol";

import "./helpers/LocalTest.sol";

import "contracts/bundlers/EVMBundler.sol";

contract EVMBundlerLocalTest is LocalTest {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    EVMBundler private bundler;

    function setUp() public override {
        super.setUp();

        bundler = new EVMBundler(address(morpho));

        vm.startPrank(USER);
        borrowableAsset.approve(address(bundler), type(uint256).max);
        collateralAsset.approve(address(bundler), type(uint256).max);
        morpho.setAuthorization(address(bundler), true);
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

    function testSetAuthorization(uint256 privateKey, uint32 deadline) public {
        privateKey = bound(privateKey, 1, type(uint32).max);
        deadline = uint32(bound(deadline, block.timestamp + 1, type(uint32).max));

        address user = vm.addr(privateKey);
        vm.assume(user != USER);

        Authorization memory authorization;
        authorization.authorizer = user;
        authorization.authorized = address(bundler);
        authorization.deadline = deadline;
        authorization.nonce = morpho.nonce(user);
        authorization.isAuthorized = true;

        bytes32 digest = SigUtils.getTypedDataHash(morpho.DOMAIN_SEPARATOR(), authorization);

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(MorphoBundler.morphoSetAuthorizationWithSig, (authorization, sig));

        bundler.multicall(block.timestamp, data);

        assertTrue(morpho.isAuthorized(user, address(bundler)), "isAuthorized(bundler)");
    }

    function testSupply(uint256 amount, address onBehalf) public {
        vm.assume(onBehalf != address(0));
        vm.assume(onBehalf != address(morpho));
        vm.assume(onBehalf != address(bundler));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableAsset), amount));
        data[1] = abi.encodeCall(MorphoBundler.morphoSupply, (marketParams, amount, 0, onBehalf, hex""));

        borrowableAsset.setBalance(USER, amount);

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        assertEq(collateralAsset.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        assertEq(borrowableAsset.balanceOf(USER), 0, "borrowable.balanceOf(USER)");

        assertEq(collateralAsset.balanceOf(onBehalf), 0, "collateral.balanceOf(onBehalf)");
        assertEq(borrowableAsset.balanceOf(onBehalf), 0, "borrowable.balanceOf(onBehalf)");

        assertEq(morpho.collateral(id, onBehalf), 0, "collateral(onBehalf)");
        assertEq(morpho.supplyShares(id, onBehalf), amount * SharesMathLib.VIRTUAL_SHARES, "supplyShares(onBehalf)");
        assertEq(morpho.borrowShares(id, onBehalf), 0, "borrowShares(onBehalf)");

        if (onBehalf != USER) {
            assertEq(morpho.collateral(id, USER), 0, "collateral(USER)");
            assertEq(morpho.supplyShares(id, USER), 0, "supplyShares(USER)");
            assertEq(morpho.borrowShares(id, USER), 0, "borrowShares(USER)");
        }
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
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(collateralAsset), collateralAmount));
        data[1] = abi.encodeCall(MorphoBundler.morphoSupplyCollateral, (marketParams, collateralAmount, USER, hex""));
        data[2] = abi.encodeCall(MorphoBundler.morphoBorrow, (marketParams, amount, 0, receiver));

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
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        bytes[] memory callbackData = new bytes[](2);
        callbackData[0] = abi.encodeCall(MorphoBundler.morphoBorrow, (marketParams, amount, 0, receiver));
        callbackData[1] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(collateralAsset), collateralAmount));

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(
            MorphoBundler.morphoSupplyCollateral, (marketParams, collateralAmount, USER, abi.encode(callbackData))
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
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        collateralAsset.setBalance(address(this), collateralAmount);
        morpho.supplyCollateral(marketParams, collateralAmount, USER, hex"");
        morpho.borrow(marketParams, amount, 0, USER, USER);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableAsset), amount));
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

        borrowableAsset.setBalance(address(this), amount);
        morpho.supply(marketParams, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        collateralAsset.setBalance(address(this), collateralAmount);
        morpho.supplyCollateral(marketParams, collateralAmount, USER, hex"");
        morpho.borrow(marketParams, amount, 0, USER, USER);

        bytes[] memory callbackData = new bytes[](2);
        callbackData[0] =
            abi.encodeCall(MorphoBundler.morphoWithdrawCollateral, (marketParams, collateralAmount, receiver));
        callbackData[1] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableAsset), amount));

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(MorphoBundler.morphoRepay, (marketParams, amount, 0, USER, abi.encode(callbackData)));

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        _testRepayWithdrawCollateral(collateralAmount, receiver);
    }
}
