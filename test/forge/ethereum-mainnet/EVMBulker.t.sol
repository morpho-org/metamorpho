// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "contracts/bulkers/EVMBulker.sol";

import "../helpers/ForkTest.sol";

contract EVMBulkerEthereumTest is ForkTest {
    using FixedPointMathLib for uint256;

    EVMBulker private bulker;

    function _network() internal pure override returns (string memory) {
        return "ethereum-mainnet";
    }

    function setUp() public override {
        super.setUp();

        bulker = new EVMBulker(address(blue));

        vm.startPrank(USER);
        blue.setAuthorization(address(bulker), true);
        blue.setAuthorization(address(this), true); // So tests can borrow/withdraw on behalf of USER without pranking it.
        vm.stopPrank();
    }

    /* INVARIANTS */

    function invariantBulkerBalanceOfZero() public {
        // assertEq(collateralAsset.balanceOf(address(bulker)), 0, "collateral.balanceOf(bulker)");
        // assertEq(borrowableAsset.balanceOf(address(bulker)), 0, "borrowable.balanceOf(bulker)");
    }

    function invariantBulkerPositionZero() public {
        // assertEq(blue.collateral(id, address(bulker)), 0, "collateral(bulker)");
        // assertEq(blue.supplyShares(id, address(bulker)), 0, "supplyShares(bulker)");
        // assertEq(blue.borrowShares(id, address(bulker)), 0, "borrowShares(bulker)");
    }

    /* TESTS */

    function testSupply(uint256 amount, address onBehalf) public {
        vm.assume(onBehalf != address(0));
        vm.assume(onBehalf != address(blue));
        vm.assume(onBehalf != address(bulker));

        amount = bound(amount, MIN_AMOUNT, MAX_AMOUNT);

        // bytes[] memory data = new bytes[](2);
        // data[0] = abi.encodeCall(ERC20Bulker.transferFrom2, (address(borrowableAsset), amount));
        // data[1] = abi.encodeCall(BlueBulker.blueSupply, (market, amount, 0, onBehalf, hex""));

        // borrowableAsset.setBalance(USER, amount);

        // vm.prank(USER);
        // bulker.multicall(block.timestamp, data);

        // assertEq(collateralAsset.balanceOf(USER), 0, "collateral.balanceOf(USER)");
        // assertEq(borrowableAsset.balanceOf(USER), 0, "borrowable.balanceOf(USER)");

        // assertEq(collateralAsset.balanceOf(onBehalf), 0, "collateral.balanceOf(onBehalf)");
        // assertEq(borrowableAsset.balanceOf(onBehalf), 0, "borrowable.balanceOf(onBehalf)");

        // assertEq(blue.collateral(id, onBehalf), 0, "collateral(onBehalf)");
        // assertEq(blue.supplyShares(id, onBehalf), amount * SharesMathLib.VIRTUAL_SHARES, "supplyShares(onBehalf)");
        // assertEq(blue.borrowShares(id, onBehalf), 0, "borrowShares(onBehalf)");

        // if (onBehalf != USER) {
        //     assertEq(blue.collateral(id, USER), 0, "collateral(USER)");
        //     assertEq(blue.supplyShares(id, USER), 0, "supplyShares(USER)");
        //     assertEq(blue.borrowShares(id, USER), 0, "borrowShares(USER)");
        // }
    }
}
