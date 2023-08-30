// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseMigrationTest.sol";

import {IPool} from "@aave/v3-core/interfaces/IPool.sol";
import {IAToken} from "@aave/v3-core/interfaces/IAToken.sol";

import {DataTypes} from "@aave/v3-core/protocol/libraries/types/DataTypes.sol";

import {AaveV3MigrationBundler} from "contracts/bundlers/migration/AaveV3MigrationBundler.sol";

contract AaveV3MigrationBundlerTest is BaseMigrationTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    AaveV3MigrationBundler bundler;

    MarketParams marketParams;

    uint256 collateralSupplied = 10_000 ether;
    uint256 supplied = 10_000 ether;
    uint256 borrowed = 1 ether;

    function setUp() public override {
        super.setUp();

        vm.label(aaveV3Pool, "Aave V3 Pool");
        vm.label(address(bundler), "Aave V3 Migration Bundler");

        marketParams = allMarketParams[0];

        bundler = new AaveV3MigrationBundler(address(morpho), address(aaveV3Pool));

        // Provide liquidity.
        deal(marketParams.borrowableToken, address(this), borrowed * 10);
        ERC20(marketParams.borrowableToken).safeApprove(address(morpho), type(uint256).max);
        morpho.supply(marketParams, borrowed * 10, 0, address(this), hex"");
    }

    /// forge-config: default.fuzz.runs = 3
    function testMigrateBorrowerWithATokenPermit(uint256 privateKey) public {
        privateKey = bound(privateKey, 1, type(uint32).max);
        address user = vm.addr(privateKey);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);

        ERC20(marketParams.collateralToken).safeApprove(aaveV3Pool, type(uint256).max);
        IPool(aaveV3Pool).supply(marketParams.collateralToken, collateralSupplied, user, 0);
        IPool(aaveV3Pool).borrow(marketParams.borrowableToken, borrowed, 2, 0, user);
        ERC20(marketParams.collateralToken).safeApprove(aaveV3Pool, 0);

        address aToken = _getATokenV3(marketParams.collateralToken);
        uint256 aTokenBalance = IAToken(aToken).balanceOf(user);

        bytes[] memory data = new bytes[](1);
        bytes[] memory callbackData = new bytes[](7);

        callbackData[0] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 0);
        callbackData[1] = _morphoBorrowCall(marketParams, borrowed, address(bundler));
        callbackData[2] = _aaveV3RepayCall(marketParams.borrowableToken, borrowed, 2);
        callbackData[3] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 1);
        callbackData[4] = _aaveV3PermitATokenCall(privateKey, aToken, address(bundler), aTokenBalance, 0);
        callbackData[5] = _erc20TransferFrom2Call(aToken, aTokenBalance);
        callbackData[6] = _aaveV3WithdrawCall(marketParams.collateralToken, address(bundler), collateralSupplied);
        data[0] = _morphoSupplyCollateralCall(marketParams, collateralSupplied, user, callbackData);

        bundler.multicall(SIG_DEADLINE, data);

        vm.stopPrank();

        assertEq(morpho.collateral(marketParams.id(), user), collateralSupplied);
        assertEq(morpho.expectedBorrowBalance(marketParams, user), borrowed);
    }

    /// forge-config: default.fuzz.runs = 3
    function testMigrateBorrowerWithPermit2(uint256 privateKey) public {
        privateKey = bound(privateKey, 1, type(uint32).max);
        address user = vm.addr(privateKey);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);

        ERC20(marketParams.collateralToken).safeApprove(aaveV3Pool, type(uint256).max);
        IPool(aaveV3Pool).supply(marketParams.collateralToken, collateralSupplied, user, 0);
        IPool(aaveV3Pool).borrow(marketParams.borrowableToken, borrowed, 2, 0, user);
        ERC20(marketParams.collateralToken).safeApprove(aaveV3Pool, 0);

        address aToken = _getATokenV3(marketParams.collateralToken);
        uint256 aTokenBalance = IAToken(aToken).balanceOf(user);

        ERC20(aToken).safeApprove(address(Permit2Lib.PERMIT2), aTokenBalance);

        bytes[] memory data = new bytes[](1);
        bytes[] memory callbackData = new bytes[](7);

        callbackData[0] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 0);
        callbackData[1] = _morphoBorrowCall(marketParams, borrowed, address(bundler));
        callbackData[2] = _aaveV3RepayCall(marketParams.borrowableToken, borrowed, 2);
        callbackData[3] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 1);
        callbackData[4] = _erc20Approve2Call(privateKey, aToken, uint160(aTokenBalance), address(bundler), 0);
        callbackData[5] = _erc20TransferFrom2Call(aToken, aTokenBalance);
        callbackData[6] = _aaveV3WithdrawCall(marketParams.collateralToken, address(bundler), collateralSupplied);
        data[0] = _morphoSupplyCollateralCall(marketParams, collateralSupplied, user, callbackData);

        bundler.multicall(SIG_DEADLINE, data);

        vm.stopPrank();

        assertEq(morpho.collateral(marketParams.id(), user), collateralSupplied);
        assertEq(morpho.expectedBorrowBalance(marketParams, user), borrowed);
    }

    function _getATokenV3(address asset) internal view returns (address) {
        DataTypes.ReserveData memory reserve = IPool(aaveV3Pool).getReserveData(asset);
        return reserve.aTokenAddress;
    }

    function _aaveV3PermitATokenCall(uint256 privateKey, address aToken, address spender, uint256 value, uint256 nonce)
        internal
        view
        returns (bytes memory)
    {
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 digest = ECDSA.toTypedDataHash(
            IAToken(aToken).DOMAIN_SEPARATOR(),
            keccak256(abi.encode(permitTypehash, vm.addr(privateKey), spender, value, nonce, SIG_DEADLINE))
        );

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        return abi.encodeCall(
            AaveV3MigrationBundler.aaveV3PermitAToken, (aToken, value, SIG_DEADLINE, sig.v, sig.r, sig.s)
        );
    }

    function _aaveV3RepayCall(address asset, uint256 amount, uint256 interestRateMode)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(AaveV3MigrationBundler.aaveV3Repay, (asset, amount, interestRateMode));
    }

    function _aaveV3WithdrawCall(address asset, address to, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(AaveV3MigrationBundler.aaveV3Withdraw, (asset, to, amount));
    }
}
