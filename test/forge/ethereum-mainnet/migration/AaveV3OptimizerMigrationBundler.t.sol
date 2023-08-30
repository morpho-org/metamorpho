// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseMigrationTest.sol";

import {IMorpho as IAaveV3Optimizer} from "@morpho-aave-v3/interfaces/IMorpho.sol";

import {AaveV3OptimizerMigrationBundler} from "contracts/bundlers/migration/AaveV3OptimizerMigrationBundler.sol";

import {Types} from "@morpho-aave-v3/libraries/Types.sol";

contract AaveV3MigrationBundlerTest is BaseMigrationTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    AaveV3OptimizerMigrationBundler bundler;

    uint256 collateralSupplied = 10_000 ether;
    uint256 supplied = 10_000 ether;
    uint256 borrowed = 1 ether;

    function setUp() public override {
        super.setUp();

        _initMarket(DAI, WETH);

        vm.label(aaveV3Optimizer, "Aave V3 Optimizer");
        vm.label(address(bundler), "Aave V3 Optimizer Migration Bundler");

        bundler = new AaveV3OptimizerMigrationBundler(address(morpho), address(aaveV3Optimizer));

        // Provide liquidity.
        deal(marketParams.borrowableToken, address(this), borrowed * 10);
        ERC20(marketParams.borrowableToken).safeApprove(address(morpho), type(uint256).max);
        morpho.supply(marketParams, borrowed * 10, 0, address(this), hex"");
    }

    /// forge-config: default.fuzz.runs = 3
    function testMigrateBorrowerWithOptimizerPermit(uint256 privateKey) public {
        privateKey = bound(privateKey, 1, type(uint32).max);
        address user = vm.addr(privateKey);
        vm.label(user, "user");

        deal(marketParams.collateralToken, user, collateralSupplied + 1);

        vm.startPrank(user);

        ERC20(marketParams.collateralToken).safeApprove(aaveV3Optimizer, type(uint256).max);
        IAaveV3Optimizer(aaveV3Optimizer).supplyCollateral(marketParams.collateralToken, collateralSupplied + 1, user);
        IAaveV3Optimizer(aaveV3Optimizer).borrow(marketParams.borrowableToken, borrowed, user, user, 15);
        ERC20(marketParams.collateralToken).safeApprove(aaveV3Optimizer, 0);

        bytes[] memory data = new bytes[](1);
        bytes[] memory callbackData = new bytes[](7);

        callbackData[0] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 0);
        callbackData[1] = _morphoBorrowCall(borrowed, address(bundler));
        callbackData[2] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), false, 1);
        callbackData[3] = _aaveV3OptimizerRepayCall(marketParams.borrowableToken, borrowed);
        callbackData[4] = _aaveV3OptimizerApproveManagerCall(privateKey, address(bundler), true, 0);
        callbackData[5] =
            _aaveV3OptimizerWithdrawCollateralCall(marketParams.collateralToken, collateralSupplied, address(bundler));
        callbackData[6] = _aaveV3OptimizerApproveManagerCall(privateKey, address(bundler), false, 1);
        data[0] = _morphoSupplyCollateralCall(collateralSupplied, user, callbackData);

        bundler.multicall(SIG_DEADLINE, data);

        vm.stopPrank();

        assertEq(morpho.collateral(marketParams.id(), user), collateralSupplied);
        assertEq(morpho.expectedBorrowBalance(marketParams, user), borrowed);
        assertFalse(morpho.isAuthorized(user, address(bundler)));
    }

    function _aaveV3OptimizerApproveManagerCall(uint256 privateKey, address manager, bool isAllowed, uint256 nonce)
        internal
        view
        returns (bytes memory)
    {
        bytes32 permitTypehash =
            keccak256("Authorization(address delegator,address manager,bool isAllowed,uint256 nonce,uint256 deadline)");
        bytes32 digest = ECDSA.toTypedDataHash(
            IAaveV3Optimizer(aaveV3Optimizer).DOMAIN_SEPARATOR(),
            keccak256(abi.encode(permitTypehash, vm.addr(privateKey), manager, isAllowed, nonce, SIG_DEADLINE))
        );

        Types.Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        return abi.encodeCall(
            AaveV3OptimizerMigrationBundler.aaveV3OptimizerApproveManagerWithSig, (isAllowed, nonce, SIG_DEADLINE, sig)
        );
    }

    function _aaveV3OptimizerRepayCall(address underlying, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(AaveV3OptimizerMigrationBundler.aaveV3OptimizerRepay, (underlying, amount));
    }

    function _aaveV3OptimizerWithdraw(address underlying, uint256 amount, address receiver, uint256 maxIterations)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            AaveV3OptimizerMigrationBundler.aaveV3OptimizerWithdraw, (underlying, amount, receiver, maxIterations)
        );
    }

    function _aaveV3OptimizerWithdrawCollateralCall(address underlying, uint256 amount, address receiver)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            AaveV3OptimizerMigrationBundler.aaveV3OptimizerWithdrawCollateral, (underlying, amount, receiver)
        );
    }
}
