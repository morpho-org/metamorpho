// // SPDX-License-Identifier: GPL-2.0-or-later
// pragma solidity ^0.8.0;

// import {SigUtils} from "test/forge/helpers/SigUtils.sol";
// import {ErrorsLib as BulkerErrorsLib} from "contracts/bundlers/libraries/ErrorsLib.sol";
// import {WETH} from "@solmate/tokens/WETH.sol";

// import "./helpers/LocalTest.sol";

// import "contracts/bundlers/WNativeBundler.sol";

// contract WNativeBundlerLocalTest is ForkTest {
//     using MathLib for uint256;
//     using MorphoLib for IMorpho;
//     using MorphoBalancesLib for IMorpho;
//     using SharesMathLib for uint256;

//     WETH internal nativeToken;
//     WNativeBundler private bundler;

//     function setUp() public override {
//         super.setUp();

//         nativeToken = new WETH();

//         bundler = new WNativeBundler(address(nativeToken));

//         vm.startPrank(USER);
//         borrowableToken.approve(address(bundler), type(uint256).max);
//         collateralToken.approve(address(bundler), type(uint256).max);
//         vm.stopPrank();
//     }

//     function testWrap0Address(uint256 amount) public {
//         vm.assume(amount != 0);

//         bytes[] memory data = new bytes[](1);
//         data[0] = abi.encodeCall(WNativeBundler.wrapNative, (amount, address(0)));

//         vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
//         vm.prank(USER);
//         bundler.multicall(block.timestamp, data);
//     }

//     function testWrap0Amount(address receiver) public {
//         vm.assume(receiver != address(bundler) && receiver != address(0));

//         bytes[] memory data = new bytes[](1);
//         data[0] = abi.encodeCall(WNativeBundler.wrapNative, (0, receiver));

//         vm.expectRevert(bytes(BulkerErrorsLib.ZERO_AMOUNT));
//         vm.prank(USER);
//         bundler.multicall(block.timestamp, data);
//     }

//     function testWrapNative(uint256 amount, address receiver) public{
//         vm.assume(receiver != address(bundler) && receiver != address(0));
//         vm.assume(amount != 0);

//         bytes[] memory data = new bytes[](1);
//         data[0] = abi.encodeCall(WNativeBundler.wrapNative, (amount, receiver));

//         vm.deal(USER, amount);
//         bundler.multicall{value: amount}(block.timestamp, data);

//         assertEq(nativeToken.balanceOf(address(bundler)), 0, "bulker's wrapped token balance");
//         assertEq(nativeToken.balanceOf(receiver), amount, "receiver's wrapped token balance");
//     }

//     function testUnwrap0Address(uint256 amount) public {
//         vm.assume(amount != 0);

//         bytes[] memory data = new bytes[](1);
//         data[0] = abi.encodeCall(WNativeBundler.unwrapNative, (amount, address(0)));

//         vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
//         vm.prank(USER);
//         bundler.multicall(block.timestamp, data);
//     }

//     function testUnwrapBundlerAddress(uint256 amount) public {
//         vm.assume(amount != 0);

//         bytes[] memory data = new bytes[](1);
//         data[0] = abi.encodeCall(WNativeBundler.unwrapNative, (amount, address(bundler)));

//         vm.expectRevert(bytes(BulkerErrorsLib.ZERO_ADDRESS));
//         vm.prank(USER);
//         bundler.multicall(block.timestamp, data);
//     }

//     function testUnwrap0Amount(address receiver) public {
//         vm.assume(receiver != address(bundler) && receiver != address(0));

//         bytes[] memory data = new bytes[](1);
//         data[0] = abi.encodeCall(WNativeBundler.unwrapNative, (0, receiver));

//         vm.expectRevert(bytes(BulkerErrorsLib.ZERO_AMOUNT));
//         vm.prank(USER);
//         bundler.multicall(block.timestamp, data);
//     }

//     function testUnwrapNative(uint256 amount, address receiver) public{
//         vm.assume(receiver != address(bundler) && receiver != address(0));
//         vm.assume(amount != 0);

//         bytes[] memory data = new bytes[](1);
//         data[0] = abi.encodeCall(WNativeBundler.unwrapNative, (amount, receiver));

//         vm.deal(USER, amount);
//         bundler.multicall{value: amount}(block.timestamp, data);
//     }
// }