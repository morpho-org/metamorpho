// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {SigUtils} from "test/forge/helpers/SigUtils.sol";
import {ErrorsLib as BulkerErrorsLib} from "contracts/bundlers/libraries/ErrorsLib.sol";

import "./helpers/LocalTest.sol";

import "contracts/bundlers/EVMBundler.sol";
import {ERC4626Mock} from "./mocks/ERC4626Mock.sol";

contract EVMBundlerLocalTest is LocalTest {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using SharesMathLib for uint256;

    EVMBundler private bundler;
    ERC4626Mock private vault;
    bytes[] private bundleData;

    function setUp() public override {
        super.setUp();

        vault = new ERC4626Mock(borrowableToken, "borrowable Vault", "BV");
        bundler = new EVMBundler(address(morpho));

        vm.startPrank(USER);
        borrowableToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);
        borrowableToken.approve(address(bundler), type(uint256).max);
        collateralToken.approve(address(bundler), type(uint256).max);
        morpho.setAuthorization(address(bundler), true);
        vm.stopPrank();
    }

    /* TESTS ERC20 BUNDLER */

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

    function testERC20ZeroAmount(address receiver, Signature calldata signature) public {
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

    function testTransfer(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0) && receiver != address(bundler));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(ERC20Bundler.transfer, (address(borrowableToken), receiver, amount));

        borrowableToken.setBalance(address(bundler), amount);
        bundler.multicall(block.timestamp, data);

        assertEq(borrowableToken.balanceOf(address(bundler)), 0, "borrowable.balanceOf(address(bundler))");
        assertEq(borrowableToken.balanceOf(receiver), amount, "borrowable.balanceOf(receiver)");
    }

    function testTransferFrom2(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableToken), amount));

        borrowableToken.setBalance(USER, amount);
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        assertEq(borrowableToken.balanceOf(address(bundler)), amount, "borrowable.balanceOf(address(bundler))");
        assertEq(borrowableToken.balanceOf(USER), 0, "borrowable.balanceOf(USER)");
    }

    /* TESTS ERC4626 BUNDLER */

    function testERC4626BundlerZeroAdress(uint256 amount, uint256 shares) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);
        shares = bound(shares, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory mintData = new bytes[](1);
        bytes[] memory depositData = new bytes[](1);
        bytes[] memory withdrawData = new bytes[](1);
        bytes[] memory redeemData = new bytes[](1);

        mintData[0] = abi.encodeCall(ERC4626Bundler.mint, (address(vault), shares, address(0)));
        depositData[0] = abi.encodeCall(ERC4626Bundler.deposit, (address(vault), amount, address(0)));
        withdrawData[0] = abi.encodeCall(ERC4626Bundler.withdraw, (address(vault), amount, address(0)));
        redeemData[0] = abi.encodeCall(ERC4626Bundler.redeem, (address(vault), shares, address(0)));

        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
        bundler.multicall(block.timestamp, mintData);
        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
        bundler.multicall(block.timestamp, depositData);
        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
        bundler.multicall(block.timestamp, withdrawData);
        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
        bundler.multicall(block.timestamp, redeemData);
    }

    function testERC4626BundlerZeroAmount(address receiver) public {
        vm.assume(receiver != address(0));

        bytes[] memory mintData = new bytes[](1);
        bytes[] memory depositData = new bytes[](1);
        bytes[] memory withdrawData = new bytes[](1);
        bytes[] memory redeemData = new bytes[](1);

        mintData[0] = abi.encodeCall(ERC4626Bundler.mint, (address(vault), 0, receiver));
        depositData[0] = abi.encodeCall(ERC4626Bundler.deposit, (address(vault), 0, receiver));
        withdrawData[0] = abi.encodeCall(ERC4626Bundler.withdraw, (address(vault), 0, receiver));
        redeemData[0] = abi.encodeCall(ERC4626Bundler.redeem, (address(vault), 0, receiver));

        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_AMOUNT));
        bundler.multicall(block.timestamp, mintData);
        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_AMOUNT));
        bundler.multicall(block.timestamp, depositData);
        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_AMOUNT));
        bundler.multicall(block.timestamp, withdrawData);
        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_SHARES));
        bundler.multicall(block.timestamp, redeemData);
    }

    function testMintVault(uint256 shares, address receiver) public {
        vm.assume(receiver != address(0));
        shares = bound(shares, MIN_AMOUNT, MAX_AMOUNT);

        uint256 expectedAmount = vault.previewMint(shares);
        vm.assume(expectedAmount != 0);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableToken), expectedAmount));
        data[1] = abi.encodeCall(ERC4626Bundler.mint, (address(vault), shares, receiver));

        borrowableToken.setBalance(USER, expectedAmount);
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        assertEq(borrowableToken.balanceOf(address(vault)), expectedAmount, "vault's balance");
        assertEq(borrowableToken.balanceOf(address(bundler)), 0, "bundler's balance");
        assertEq(vault.balanceOf(receiver), shares, "receiver's shares");
    }

    function testDepositVault(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        uint256 expectedShares = vault.previewDeposit(amount);
        vm.assume(expectedShares != 0);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableToken), amount));
        data[1] = abi.encodeCall(ERC4626Bundler.deposit, (address(vault), amount, receiver));

        borrowableToken.setBalance(USER, amount);
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        assertEq(borrowableToken.balanceOf(address(vault)), amount, "vault's balance");
        assertEq(borrowableToken.balanceOf(address(bundler)), 0, "bundler's balance");
        assertEq(vault.balanceOf(receiver), expectedShares, "receiver's shares");
    }

    function testWithdrawVault(uint256 depositedAmount, uint256 withdrawnAmount, address receiver) public {
        vm.assume(receiver != address(0));
        depositedAmount = bound(depositedAmount, MIN_AMOUNT, MAX_AMOUNT);

        uint256 suppliedShares = depositOnVault(depositedAmount);

        withdrawnAmount = bound(withdrawnAmount, MIN_AMOUNT, depositedAmount);
        uint256 withdrawnShares = vault.previewWithdraw(withdrawnAmount);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(ERC4626Bundler.withdraw, (address(vault), withdrawnAmount, receiver));

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        assertEq(borrowableToken.balanceOf(address(vault)), depositedAmount - withdrawnAmount, "vault's balance");
        assertEq(borrowableToken.balanceOf(address(bundler)), 0, "bundler's balance");
        assertEq(borrowableToken.balanceOf(receiver), withdrawnAmount, "bundler's balance");
        assertEq(vault.balanceOf(USER), suppliedShares - withdrawnShares, "receiver's shares");
    }

    function testRedeemVault(uint256 depositedAmount, uint256 redeemedShares, address receiver) public {
        vm.assume(receiver != address(0));
        depositedAmount = bound(depositedAmount, MIN_AMOUNT, MAX_AMOUNT);

        uint256 suppliedShares = depositOnVault(depositedAmount);

        redeemedShares = bound(redeemedShares, MIN_AMOUNT, suppliedShares);
        uint256 withdrawnAmount = vault.previewRedeem(redeemedShares);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(ERC4626Bundler.redeem, (address(vault), redeemedShares, receiver));

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        assertEq(borrowableToken.balanceOf(address(vault)), depositedAmount - withdrawnAmount, "vault's balance");
        assertEq(borrowableToken.balanceOf(address(bundler)), 0, "bundler's balance");
        assertEq(borrowableToken.balanceOf(receiver), withdrawnAmount, "bundler's balance");
        assertEq(vault.balanceOf(USER), suppliedShares - redeemedShares, "receiver's shares");
    }

    function depositOnVault(uint256 amount) internal returns (uint256 shares) {
        shares = vault.previewDeposit(amount);

        borrowableToken.setBalance(USER, amount);
        vm.startPrank(USER);
        borrowableToken.approve(address(vault), type(uint256).max);
        vault.deposit(amount, USER);
        vault.approve(address(bundler), type(uint256).max);
        vm.stopPrank();
    }

    /* TESTS MORPHO BUNDLER */

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

    function testSupply(uint256 amount, address onBehalf) public {
        vm.assume(onBehalf != address(0));
        vm.assume(onBehalf != address(morpho));
        vm.assume(onBehalf != address(bundler));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(borrowableToken), amount));
        data[1] = abi.encodeCall(MorphoBundler.morphoSupply, (marketParams, amount, 0, onBehalf, hex""));

        borrowableToken.setBalance(USER, amount);

        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        assertEq(collateralToken.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        assertEq(borrowableToken.balanceOf(USER), 0, "borrowable.balanceOf(USER)");

        assertEq(collateralToken.balanceOf(onBehalf), 0, "collateral.balanceOf(onBehalf)");
        assertEq(borrowableToken.balanceOf(onBehalf), 0, "borrowable.balanceOf(onBehalf)");

        assertEq(morpho.collateral(id, onBehalf), 0, "collateral(onBehalf)");
        assertEq(morpho.supplyShares(id, onBehalf), amount * SharesMathLib.VIRTUAL_SHARES, "supplyShares(onBehalf)");
        assertEq(morpho.borrowShares(id, onBehalf), 0, "borrowShares(onBehalf)");

        if (onBehalf != USER) {
            assertEq(morpho.collateral(id, USER), 0, "collateral(USER)");
            assertEq(morpho.supplyShares(id, USER), 0, "supplyShares(USER)");
            assertEq(morpho.borrowShares(id, USER), 0, "borrowShares(USER)");
        }
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
        uint256 expectedSupplyShares = amount.toSharesDown(0, 0);
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
        assertEq(
            borrowableToken.balanceOf(address(morpho)),
            amount - expectedWithdrawnAmount,
            "borrowable.balanceOf(address(morpho))"
        );

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

    struct BundleTransactionsVars {
        uint256 expectedSupplyShares;
        uint256 expectedBorrowShares;
        uint256 expectedTotalSupply;
        uint256 expectedTotalBorrow;
        uint256 expectedCollateral;
        uint256 expectedBundlerBorrowableBalance;
        uint256 expectedBundlerCollateralBalance;
        uint256 initialUserBorrowableBalance;
        uint256 initialUserCollateralBalance;
    }

    function testBundleTransactions(uint256 size, uint256 seedAction, uint256 seedAmount) public {
        seedAction = bound(seedAction, 0, type(uint256).max - 30);
        seedAmount = bound(seedAmount, 0, type(uint256).max - 30);

        BundleTransactionsVars memory vars;

        for (uint256 i; i < size % 30; ++i) {
            uint256 actionId = uint256(keccak256(abi.encode(seedAmount + i))) % 11;
            uint256 amount = uint256(keccak256(abi.encode(seedAmount + i)));
            if (actionId < 3) _addSupplyData(vars, amount);
            else if (actionId < 6) _addSupplyCollateralData(vars, amount);
            else if (actionId < 8) _addBorrowData(vars, amount);
            else if (actionId < 9) _addRepayData(vars, amount);
            else if (actionId < 10) _addWithdrawData(vars, amount);
            else if (actionId == 10) _addWithdrawCollateralData(vars, amount);
        }

        borrowableToken.setBalance(USER, vars.initialUserBorrowableBalance);
        collateralToken.setBalance(USER, vars.initialUserCollateralBalance);

        vm.prank(USER);
        bundler.multicall(block.timestamp, bundleData);

        assertEq(morpho.supplyShares(id, USER), vars.expectedSupplyShares, "User's supply shares");
        assertEq(morpho.borrowShares(id, USER), vars.expectedBorrowShares, "User's borrow shares");
        assertEq(morpho.totalSupplyShares(id), vars.expectedSupplyShares, "Total supply shares");
        assertEq(morpho.totalBorrowShares(id), vars.expectedBorrowShares, "Total borrow shares");
        assertEq(morpho.totalSupplyAssets(id), vars.expectedTotalSupply, "Total supply");
        assertEq(morpho.totalBorrowAssets(id), vars.expectedTotalBorrow, "Total borrow");
        assertEq(morpho.collateral(id, USER), vars.expectedCollateral, "User's collateral");

        assertEq(borrowableToken.balanceOf(USER), 0, "User's borrowable balance");
        assertEq(collateralToken.balanceOf(USER), 0, "User's collateral balance");
        assertEq(
            borrowableToken.balanceOf(address(morpho)),
            vars.expectedTotalSupply - vars.expectedTotalBorrow,
            "User's borrowable balance"
        );
        assertEq(collateralToken.balanceOf(address(morpho)), vars.expectedCollateral, "Morpho's collateral balance");
        assertEq(
            borrowableToken.balanceOf(address(bundler)),
            vars.expectedBundlerBorrowableBalance,
            "Bundler's borrowable balance"
        );
        assertEq(
            collateralToken.balanceOf(address(bundler)),
            vars.expectedBundlerCollateralBalance,
            "Bundler's collateral balance"
        );
    }

    function _getTransferData(address token, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodeCall(ERC20Bundler.transfer, (token, USER, amount));
    }

    function _getTransferFrom2Data(address token, uint256 amount) internal pure returns (bytes memory data) {
        data = abi.encodeCall(ERC20Bundler.transferFrom2, (token, amount));
    }

    function _getSupplyData(uint256 amount) internal view returns (bytes memory data) {
        data = abi.encodeCall(MorphoBundler.morphoSupply, (marketParams, amount, 0, USER, hex""));
    }

    function _getSupplyCollateralData(uint256 amount) internal view returns (bytes memory data) {
        data = abi.encodeCall(MorphoBundler.morphoSupplyCollateral, (marketParams, amount, USER, hex""));
    }

    function _getWithdrawData(uint256 amount) internal view returns (bytes memory data) {
        data = abi.encodeCall(MorphoBundler.morphoWithdraw, (marketParams, amount, 0, address(bundler)));
    }

    function _getWithdrawCollateralData(uint256 amount) internal view returns (bytes memory data) {
        data = abi.encodeCall(MorphoBundler.morphoWithdrawCollateral, (marketParams, amount, address(bundler)));
    }

    function _getBorrowData(uint256 shares) internal view returns (bytes memory data) {
        data = abi.encodeCall(MorphoBundler.morphoBorrow, (marketParams, 0, shares, address(bundler)));
    }

    function _getRepayData(uint256 amount) internal view returns (bytes memory data) {
        data = abi.encodeCall(MorphoBundler.morphoRepay, (marketParams, amount, 0, USER, hex""));
    }

    function _addSupplyData(BundleTransactionsVars memory vars, uint256 amount) internal {
        amount = bound(amount % MAX_AMOUNT, MIN_AMOUNT, MAX_AMOUNT);

        _transferMissingBorrowable(vars, amount);

        bundleData.push(_getSupplyData(amount));
        vars.expectedBundlerBorrowableBalance -= amount;

        uint256 expectedAddedSupplyShares = amount.toSharesDown(vars.expectedTotalSupply, vars.expectedSupplyShares);
        vars.expectedTotalSupply += amount;
        vars.expectedSupplyShares += expectedAddedSupplyShares;
    }

    function _addSupplyCollateralData(BundleTransactionsVars memory vars, uint256 amount) internal {
        amount = bound(amount % MAX_AMOUNT, MIN_AMOUNT, MAX_AMOUNT);

        _transferMissingCollateral(vars, amount);

        bundleData.push(_getSupplyCollateralData(amount));
        vars.expectedBundlerCollateralBalance -= amount;

        vars.expectedCollateral += amount;
    }

    function _addWithdrawData(BundleTransactionsVars memory vars, uint256 amount) internal {
        uint256 availableLiquidity = vars.expectedTotalSupply - vars.expectedTotalBorrow;
        if (availableLiquidity == 0 || vars.expectedSupplyShares == 0) return;

        uint256 supplyBalance =
            vars.expectedSupplyShares.toAssetsDown(vars.expectedTotalSupply, vars.expectedSupplyShares);

        uint256 maxAmount = UtilsLib.min(supplyBalance, availableLiquidity);
        amount = bound(amount % maxAmount, 1, maxAmount);

        bundleData.push(_getWithdrawData(amount));
        vars.expectedBundlerBorrowableBalance += amount;

        uint256 expectedDecreasedSupplyShares = amount.toSharesUp(vars.expectedTotalSupply, vars.expectedSupplyShares);
        vars.expectedTotalSupply -= amount;
        vars.expectedSupplyShares -= expectedDecreasedSupplyShares;
    }

    function _addBorrowData(BundleTransactionsVars memory vars, uint256 shares) internal {
        uint256 availableLiquidity = vars.expectedTotalSupply - vars.expectedTotalBorrow;
        if (availableLiquidity == 0 || vars.expectedCollateral == 0) return;

        uint256 totalBorrowPower = vars.expectedCollateral.wMulDown(marketParams.lltv);

        uint256 borrowed = vars.expectedBorrowShares.toAssetsUp(vars.expectedTotalBorrow, vars.expectedBorrowShares);

        uint256 currentBorrowPower = totalBorrowPower - borrowed;
        if (currentBorrowPower == 0) return;

        uint256 maxShares = UtilsLib.min(currentBorrowPower, availableLiquidity).toSharesDown(
            vars.expectedTotalBorrow, vars.expectedBorrowShares
        );
        if (maxShares < MIN_AMOUNT) return;
        shares = bound(shares % maxShares, MIN_AMOUNT, maxShares);

        bundleData.push(_getBorrowData(shares));
        uint256 expectedBorrowedAmount = shares.toAssetsDown(vars.expectedTotalBorrow, vars.expectedBorrowShares);
        vars.expectedBundlerBorrowableBalance += expectedBorrowedAmount;

        vars.expectedTotalBorrow += expectedBorrowedAmount;
        vars.expectedBorrowShares += shares;
    }

    function _addRepayData(BundleTransactionsVars memory vars, uint256 amount) internal {
        if (vars.expectedBorrowShares == 0) return;

        uint256 borrowBalance =
            vars.expectedBorrowShares.toAssetsDown(vars.expectedTotalBorrow, vars.expectedBorrowShares);

        amount = bound(amount % borrowBalance, 1, borrowBalance);

        _transferMissingBorrowable(vars, amount);

        bundleData.push(_getRepayData(amount));
        vars.expectedBundlerBorrowableBalance -= amount;

        uint256 expectedDecreasedBorrowShares = amount.toSharesDown(vars.expectedTotalBorrow, vars.expectedBorrowShares);
        vars.expectedTotalBorrow -= amount;
        vars.expectedBorrowShares -= expectedDecreasedBorrowShares;
    }

    function _addWithdrawCollateralData(BundleTransactionsVars memory vars, uint256 amount) internal {
        if (vars.expectedCollateral == 0) return;

        uint256 borrowPower = vars.expectedCollateral.wMulDown(marketParams.lltv);
        uint256 borrowed = vars.expectedBorrowShares.toAssetsUp(vars.expectedTotalBorrow, vars.expectedBorrowShares);

        uint256 withdrawableCollateral = (borrowPower - borrowed).wDivDown(marketParams.lltv);
        if (withdrawableCollateral == 0) return;

        amount = bound(amount % withdrawableCollateral, 1, withdrawableCollateral);

        bundleData.push(_getWithdrawCollateralData(amount));
        vars.expectedBundlerCollateralBalance += amount;

        vars.expectedCollateral -= amount;
    }

    function _transferMissingBorrowable(BundleTransactionsVars memory vars, uint256 amount) internal {
        if (amount > vars.expectedBundlerBorrowableBalance) {
            uint256 missingAmount = amount - vars.expectedBundlerBorrowableBalance;
            bundleData.push(_getTransferFrom2Data(address(borrowableToken), missingAmount));
            vars.initialUserBorrowableBalance += missingAmount;
            vars.expectedBundlerBorrowableBalance += missingAmount;
        }
    }

    function _transferMissingCollateral(BundleTransactionsVars memory vars, uint256 amount) internal {
        if (amount > vars.expectedBundlerCollateralBalance) {
            uint256 missingAmount = amount - vars.expectedBundlerCollateralBalance;
            bundleData.push(_getTransferFrom2Data(address(collateralToken), missingAmount));
            vars.initialUserCollateralBalance += missingAmount;
            vars.expectedBundlerCollateralBalance += missingAmount;
        }
    }
}
