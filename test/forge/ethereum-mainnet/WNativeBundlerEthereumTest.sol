// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {SigUtils} from "test/forge/helpers/SigUtils.sol";
import {ErrorsLib as BulkerErrorsLib} from "contracts/bundlers/libraries/ErrorsLib.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import "../helpers/ForkTest.sol";

import "contracts/bundlers/mocks/WNativeBundlerMock.sol";

contract WNativeBundlerForkTest is ForkTest {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using SharesMathLib for uint256;

    WNativeBundlerMock private bundler;

    function _network() internal pure override returns (string memory) {
        return "ethereum-mainnet";
    }

    function setUp() public override {
        super.setUp();

        bundler = new WNativeBundlerMock(WETH);

        vm.startPrank(USER);
        IERC20(WETH).approve(address(bundler), type(uint256).max);
        vm.stopPrank();
    }

    function testWrap0Address(uint256 amount) public {
        vm.assume(amount != 0);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(WNativeBundler.wrapNative, (amount, address(0)));

        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);
    }

    function testWrap0Amount(address receiver) public {
        vm.assume(receiver != address(bundler) && receiver != address(0));

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(WNativeBundler.wrapNative, (0, receiver));

        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_AMOUNT));
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);
    }

    function testWrapNative(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(WNativeBundler.wrapNative, (amount, RECEIVER));

        vm.deal(USER, amount);
        vm.prank(USER);
        bundler.multicall{value: amount}(block.timestamp, data);

        assertEq(IERC20(WETH).balanceOf(address(bundler)), 0, "Bundler's wrapped token balance");
        assertEq(IERC20(WETH).balanceOf(USER), 0, "User's wrapped token balance");
        assertEq(IERC20(WETH).balanceOf(RECEIVER), amount, "Receiver's wrapped token balance");

        assertEq(address(bundler).balance, 0, "Bundler's native token balance");
        assertEq(USER.balance, 0, "User's native token balance");
        assertEq(RECEIVER.balance, 0, "Receiver's native token balance");
    }

    function testUnwrap0Address(uint256 amount) public {
        vm.assume(amount != 0);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(WNativeBundler.unwrapNative, (amount, address(0)));

        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);
    }

    function testUnwrapBundlerAddress(uint256 amount) public {
        vm.assume(amount != 0);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(WNativeBundler.unwrapNative, (amount, address(bundler)));

        vm.expectRevert(bytes(BulkerErrorsLib.BUNDLER_ADDRESS));
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);
    }

    function testUnwrap0Amount(address receiver) public {
        vm.assume(receiver != address(bundler) && receiver != address(0));

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(WNativeBundler.unwrapNative, (0, receiver));

        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_AMOUNT));
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);
    }

    function testUnwrapNative(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(ERC20Bundler.transferFrom2, (address(WETH), amount));
        data[1] = abi.encodeCall(WNativeBundler.unwrapNative, (amount, RECEIVER));

        console2.log(USER.balance);
        console2.log(RECEIVER.balance);

        deal(WETH, USER, amount);

        console2.log(IERC20(WETH).balanceOf(USER));

        vm.startPrank(USER);
        IERC20(WETH).approve(address(bundler), amount);
        bundler.multicall(block.timestamp, data);
        vm.stopPrank();

        assertEq(IERC20(WETH).balanceOf(address(bundler)), 0, "Bundler's wrapped token balance");
        assertEq(IERC20(WETH).balanceOf(USER), 0, "User's wrapped token balance");
        assertEq(IERC20(WETH).balanceOf(RECEIVER), 0, "Receiver's wrapped token balance");

        assertEq(address(bundler).balance, 0, "Bundler's native token balance");
        assertEq(USER.balance, 0, "User's native token balance");
        assertEq(RECEIVER.balance, amount, "Receiver's native token balance");
    }
}
