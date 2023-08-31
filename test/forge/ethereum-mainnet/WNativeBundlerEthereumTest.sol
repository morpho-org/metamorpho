// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {SigUtils} from "test/forge/helpers/SigUtils.sol";
import {ErrorsLib as BulkerErrorsLib} from "contracts/bundlers/libraries/ErrorsLib.sol";

import "../helpers/ForkTest.sol";

import "../mocks/WNativeBundlerMock.sol";

contract WNativeBundlerForkTest is ForkTest {
    WNativeBundlerMock private bundler;

    function _network() internal pure override returns (string memory) {
        return "ethereum-mainnet";
    }

    function setUp() public override {
        super.setUp();

        bundler = new WNativeBundlerMock(WETH);

        vm.prank(USER);
        ERC20(WETH).approve(address(bundler), type(uint256).max);
    }

    function testWrapZeroAddress(uint256 amount) public {
        vm.assume(amount != 0);

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(WNativeBundler.wrapNative, (amount, address(0)));

        vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);
    }

    function testWrapZeroAmount(address receiver) public {
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

        assertEq(ERC20(WETH).balanceOf(address(bundler)), 0, "Bundler's wrapped token balance");
        assertEq(ERC20(WETH).balanceOf(USER), 0, "User's wrapped token balance");
        assertEq(ERC20(WETH).balanceOf(RECEIVER), amount, "Receiver's wrapped token balance");

        assertEq(address(bundler).balance, 0, "Bundler's native token balance");
        assertEq(USER.balance, 0, "User's native token balance");
        assertEq(RECEIVER.balance, 0, "Receiver's native token balance");
    }

    function testUnwrapZeroAddress(uint256 amount) public {
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

    function testUnwrapZeroAmount(address receiver) public {
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

        deal(WETH, USER, amount);
        vm.prank(USER);
        bundler.multicall(block.timestamp, data);

        assertEq(ERC20(WETH).balanceOf(address(bundler)), 0, "Bundler's wrapped token balance");
        assertEq(ERC20(WETH).balanceOf(USER), 0, "User's wrapped token balance");
        assertEq(ERC20(WETH).balanceOf(RECEIVER), 0, "Receiver's wrapped token balance");

        assertEq(address(bundler).balance, 0, "Bundler's native token balance");
        assertEq(USER.balance, 0, "User's native token balance");
        assertEq(RECEIVER.balance, amount, "Receiver's native token balance");
    }
}
