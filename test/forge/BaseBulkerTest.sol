// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// import {SigUtils} from "@morpho-blue/../test/helpers/SigUtils.sol";

import "@morpho-blue/Blue.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {OracleMock} from "@morpho-blue/mocks/OracleMock.sol";
import {IrmMock} from "@morpho-blue/mocks/IrmMock.sol";

import "contracts/bulkers/EVMBulker.sol";

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";

contract BaseBulkerTest is Test {
    using MarketLib for Market;
    using SharesMathLib for uint256;
    using stdStorage for StdStorage;
    using FixedPointMathLib for uint256;

    uint256 internal constant MIN_AMOUNT = 1000;
    uint256 internal constant MAX_AMOUNT = 2 ** 64;

    address private constant USER = address(0x1234);
    address private constant SUPPLIER = address(0x5678);
    uint256 private constant LLTV = 0.8 ether;
    address private constant OWNER = address(0xdead);

    Blue private blue;
    ERC20Mock private borrowableAsset;
    ERC20Mock private collateralAsset;
    OracleMock private oracle;
    IrmMock private irm;
    Market private market;
    Id private id;

    EVMBulker private bulker;

    function setUp() public {
        // Create Blue.
        blue = new Blue(OWNER);

        // List a market.
        borrowableAsset = new ERC20Mock("borrowable", "B", 18);
        collateralAsset = new ERC20Mock("collateral", "C", 18);
        oracle = new OracleMock();

        irm = new IrmMock(blue);

        market = Market(address(borrowableAsset), address(collateralAsset), address(oracle), address(irm), LLTV);
        id = market.id();

        vm.startPrank(OWNER);
        blue.enableIrm(address(irm));
        blue.enableLltv(LLTV);
        blue.createMarket(market);
        vm.stopPrank();

        oracle.setPrice(WAD);

        bulker = new EVMBulker(address(blue));

        borrowableAsset.approve(address(blue), type(uint256).max);
        collateralAsset.approve(address(blue), type(uint256).max);

        vm.startPrank(USER);
        borrowableAsset.approve(address(bulker), type(uint256).max);
        collateralAsset.approve(address(bulker), type(uint256).max);
        blue.setAuthorization(address(bulker), true);
        vm.stopPrank();

        vm.prank(SUPPLIER);
        borrowableAsset.approve(address(blue), type(uint256).max);
    }

    function testSupplyCollateralBorrow(uint256 amount, address receiver) public {
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
    }
}
