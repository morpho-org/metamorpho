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
        blue.setAuthorization(address(this), true); // So tests can borrow/withdraw on behalf of USER without pranking it.
        vm.stopPrank();
    }

    /* INVARIANTS */

    function invariantBulkerBalanceOfZero() public {
        assertEq(collateralAsset.balanceOf(address(bulker)), 0, "collateral.balanceOf(bulker)");
        assertEq(borrowableAsset.balanceOf(address(bulker)), 0, "borrowable.balanceOf(bulker)");
    }

    function invariantBulkerPositionZero() public {
        assertEq(blue.collateral(id, address(bulker)), 0, "collateral(bulker)");
        assertEq(blue.supplyShares(id, address(bulker)), 0, "supplyShares(bulker)");
        assertEq(blue.borrowShares(id, address(bulker)), 0, "borrowShares(bulker)");
    }

    /* TESTS */

    function testSetAuthorization(uint256 privateKey, uint32 deadline) public {
        privateKey = bound(privateKey, 1, type(uint32).max);
        deadline = uint32(bound(deadline, block.timestamp + 1, type(uint32).max));

        address user = vm.addr(privateKey);
        vm.assume(user != USER);

        bytes32 digest = ECDSA.toTypedDataHash(
            blue.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(AUTHORIZATION_TYPEHASH, user, address(bulker), true, blue.nonce(user), deadline))
        );

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(BlueBulker.blueSetAuthorization, (user, true, deadline, sig));

        bulker.multicall(block.timestamp, data);

        assertTrue(blue.isAuthorized(user, address(bulker)), "isAuthorized(bulker)");
    }

    function testSupply(uint256 amount, address onBehalf) public {
        vm.assume(onBehalf != address(0));
        vm.assume(onBehalf != address(blue));
        vm.assume(onBehalf != address(bulker));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(ERC20Bulker.transferFrom2, (address(borrowableAsset), amount));
        data[1] = abi.encodeCall(BlueBulker.blueSupply, (market, amount, 0, onBehalf, hex""));

        borrowableAsset.setBalance(USER, amount);

        vm.prank(USER);
        bulker.multicall(block.timestamp, data);

        assertEq(collateralAsset.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        assertEq(borrowableAsset.balanceOf(USER), 0, "borrowable.balanceOf(USER)");

        assertEq(collateralAsset.balanceOf(onBehalf), 0, "collateral.balanceOf(onBehalf)");
        assertEq(borrowableAsset.balanceOf(onBehalf), 0, "borrowable.balanceOf(onBehalf)");

        assertEq(blue.collateral(id, onBehalf), 0, "collateral(onBehalf)");
        assertEq(blue.supplyShares(id, onBehalf), amount * SharesMathLib.VIRTUAL_SHARES, "supplyShares(onBehalf)");
        assertEq(blue.borrowShares(id, onBehalf), 0, "borrowShares(onBehalf)");

        if (onBehalf != USER) {
            assertEq(blue.collateral(id, USER), 0, "collateral(USER)");
            assertEq(blue.supplyShares(id, USER), 0, "supplyShares(USER)");
            assertEq(blue.borrowShares(id, USER), 0, "borrowShares(USER)");
        }
    }

    function _testSupplyCollateralBorrow(uint256 amount, uint256 collateralAmount, address receiver) internal {
        assertEq(collateralAsset.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        assertEq(borrowableAsset.balanceOf(USER), 0, "borrowable.balanceOf(USER)");

        assertEq(collateralAsset.balanceOf(receiver), 0, "collateral.balanceOf(receiver)");
        assertEq(borrowableAsset.balanceOf(receiver), amount, "borrowable.balanceOf(receiver)");

        assertEq(blue.collateral(id, USER), collateralAmount, "collateral(USER)");
        assertEq(blue.supplyShares(id, USER), 0, "supplyShares(USER)");
        assertEq(blue.borrowShares(id, USER), amount * SharesMathLib.VIRTUAL_SHARES, "borrowShares(USER)");

        if (receiver != USER) {
            assertEq(blue.collateral(id, receiver), 0, "collateral(receiver)");
            assertEq(blue.supplyShares(id, receiver), 0, "supplyShares(receiver)");
            assertEq(blue.borrowShares(id, receiver), 0, "borrowShares(receiver)");
        }
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

        _testSupplyCollateralBorrow(amount, collateralAmount, receiver);
    }

    function testSupplyCollateralBorrowViaCallback(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(blue));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        borrowableAsset.setBalance(address(this), amount);
        blue.supply(market, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        bytes[] memory callbackData = new bytes[](2);
        callbackData[0] = abi.encodeCall(BlueBulker.blueBorrow, (market, amount, 0, receiver));
        callbackData[1] = abi.encodeCall(ERC20Bulker.transferFrom2, (address(collateralAsset), collateralAmount));

        bytes[] memory data = new bytes[](1);
        data[0] =
            abi.encodeCall(BlueBulker.blueSupplyCollateral, (market, collateralAmount, USER, abi.encode(callbackData)));

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

        assertEq(blue.collateral(id, USER), 0, "collateral(USER)");
        assertEq(blue.supplyShares(id, USER), 0, "supplyShares(USER)");
        assertEq(blue.borrowShares(id, USER), 0, "borrowShares(USER)");

        if (receiver != USER) {
            assertEq(blue.collateral(id, receiver), 0, "collateral(receiver)");
            assertEq(blue.supplyShares(id, receiver), 0, "supplyShares(receiver)");
            assertEq(blue.borrowShares(id, receiver), 0, "borrowShares(receiver)");
        }
    }

    function testRepayWithdrawCollateral(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(blue));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        borrowableAsset.setBalance(address(this), amount);
        blue.supply(market, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        collateralAsset.setBalance(address(this), collateralAmount);
        blue.supplyCollateral(market, collateralAmount, USER, hex"");
        blue.borrow(market, amount, 0, USER, USER);

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(ERC20Bulker.transferFrom2, (address(borrowableAsset), amount));
        data[1] = abi.encodeCall(BlueBulker.blueRepay, (market, amount, 0, USER, hex""));
        data[2] = abi.encodeCall(BlueBulker.blueWithdrawCollateral, (market, collateralAmount, receiver));

        vm.prank(USER);
        bulker.multicall(block.timestamp, data);

        _testRepayWithdrawCollateral(collateralAmount, receiver);
    }

    function testRepayWithdrawCollateralViaCallback(uint256 amount, address receiver) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(blue));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        borrowableAsset.setBalance(address(this), amount);
        blue.supply(market, amount, 0, SUPPLIER, hex"");

        uint256 collateralAmount = amount.wDivUp(LLTV);

        collateralAsset.setBalance(address(this), collateralAmount);
        blue.supplyCollateral(market, collateralAmount, USER, hex"");
        blue.borrow(market, amount, 0, USER, USER);

        bytes[] memory callbackData = new bytes[](2);
        callbackData[0] = abi.encodeCall(BlueBulker.blueWithdrawCollateral, (market, collateralAmount, receiver));
        callbackData[1] = abi.encodeCall(ERC20Bulker.transferFrom2, (address(borrowableAsset), amount));

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(BlueBulker.blueRepay, (market, amount, 0, USER, abi.encode(callbackData)));

        vm.prank(USER);
        bulker.multicall(block.timestamp, data);

        _testRepayWithdrawCollateral(collateralAmount, receiver);
    }
}
