// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseMigrationTest.sol";

import {ILendingPool} from "@morpho-v1/aave-v2/interfaces/aave/ILendingPool.sol";
import {IAToken} from "@morpho-v1/aave-v2/interfaces/aave/IAToken.sol";

import {DataTypes} from "@morpho-v1/aave-v2/libraries/aave/DataTypes.sol";

import {AaveV2MigrationBundler} from "contracts/bundlers/migration/AaveV2MigrationBundler.sol";

contract AaveV2MigrationBundlerTest is BaseMigrationTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    AaveV2MigrationBundler bundler;

    MarketParams marketParams;

    uint256 collateralSupplied = 10_000 ether;
    uint256 supplied = 10_000 ether;
    uint256 borrowed = 1 ether;

    function setUp() public override {
        super.setUp();

        vm.label(aaveV2LendingPool, "Aave V2 Pool");
        vm.label(address(bundler), "Aave V2 Migration Bundler");

        marketParams = allMarketParams[0];

        bundler = new AaveV2MigrationBundler(address(morpho), address(aaveV2LendingPool));

        // Provide liquidity.
        deal(marketParams.borrowableToken, address(this), borrowed * 10);
        ERC20(marketParams.borrowableToken).safeApprove(address(morpho), type(uint256).max);
        morpho.supply(marketParams, borrowed * 10, 0, address(this), hex"");
    }

    /// forge-config: default.fuzz.runs = 3
    function testMigrateBorrowerWithPermit2(uint256 privateKey) public {
        privateKey = bound(privateKey, 1, type(uint32).max);
        address user = vm.addr(privateKey);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);

        ERC20(marketParams.collateralToken).safeApprove(aaveV2LendingPool, type(uint256).max);
        ILendingPool(aaveV2LendingPool).deposit(marketParams.collateralToken, collateralSupplied, user, 0);
        ILendingPool(aaveV2LendingPool).borrow(marketParams.borrowableToken, borrowed, 2, 0, user);
        ERC20(marketParams.collateralToken).safeApprove(aaveV2LendingPool, 0);

        address aToken = _getATokenV2(marketParams.collateralToken);
        uint256 aTokenBalance = IAToken(aToken).balanceOf(user);

        ERC20(aToken).safeApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        bytes[] memory data = new bytes[](1);
        bytes[] memory callbackData = new bytes[](7);

        callbackData[0] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 0);
        callbackData[1] = _morphoBorrowCall(marketParams, borrowed, address(bundler));
        callbackData[2] = _aaveV2RepayCall(marketParams.borrowableToken, borrowed, 2);
        callbackData[3] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 1);
        callbackData[4] = _erc20Approve2Call(privateKey, aToken, uint160(aTokenBalance), address(bundler), 0);
        callbackData[5] = _erc20TransferFrom2Call(aToken, aTokenBalance);
        callbackData[6] = _aaveV2WithdrawCall(marketParams.collateralToken, collateralSupplied, address(bundler));
        data[0] = _morphoSupplyCollateralCall(marketParams, collateralSupplied, user, callbackData);

        bundler.multicall(SIG_DEADLINE, data);

        vm.stopPrank();

        assertEq(morpho.collateral(marketParams.id(), user), collateralSupplied);
        assertEq(morpho.expectedBorrowBalance(marketParams, user), borrowed);
    }

    function _getATokenV2(address asset) internal view returns (address) {
        DataTypes.ReserveData memory reserve = ILendingPool(aaveV2LendingPool).getReserveData(asset);
        return reserve.aTokenAddress;
    }

    function _aaveV2RepayCall(address asset, uint256 amount, uint256 rateMode)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(AaveV2MigrationBundler.aaveV2Repay, (asset, amount, rateMode));
    }

    function _aaveV2WithdrawCall(address asset, uint256 amount, address to) internal pure returns (bytes memory) {
        return abi.encodeCall(AaveV2MigrationBundler.aaveV2Withdraw, (asset, amount, to));
    }
}
