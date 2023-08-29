// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseMigrationTest.sol";

import {IPool} from "@aave/v3-core/interfaces/IPool.sol";
import {IAToken} from "@aave/v3-core/interfaces/IAToken.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {DataTypes} from "@aave/v3-core/protocol/libraries/types/DataTypes.sol";

import {AaveV3MigrationBundler} from "contracts/bundlers/migration/AaveV3MigrationBundler.sol";

contract AaveV3MigrationBundlerTest is BaseMigrationTest {
    using SafeTransferLib for ERC20;

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
    function testMigrateBorrower(uint256 privateKey) public {
        privateKey = bound(privateKey, 1, type(uint32).max);
        address user = vm.addr(privateKey);

        deal(marketParams.collateralToken, user, collateralSupplied + 100);

        vm.startPrank(user);

        ERC20(marketParams.collateralToken).safeApprove(aaveV3Pool, type(uint256).max);
        IPool(aaveV3Pool).supply(marketParams.collateralToken, collateralSupplied + 100, user, 0);
        IPool(aaveV3Pool).borrow(marketParams.borrowableToken, borrowed, 2, 0, user);
        ERC20(marketParams.collateralToken).safeApprove(aaveV3Pool, 0);

        address aToken = _getATokenV3(marketParams.collateralToken);
        uint256 aTokenBalance = IAToken(aToken).balanceOf(user);

        bytes[] memory data = new bytes[](1);
        bytes[] memory callbackData = new bytes[](7);

        // Authorize the Bundler to manage user's position on Morpho.
        callbackData[0] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 0);

        // Borrow from Morpho.
        callbackData[1] = _morphoBorrowCall(marketParams, borrowed, address(bundler));

        // Repay the debt on Aave on behalf of the user.
        callbackData[2] = _aaveV3RepayCall(marketParams.borrowableToken, borrowed, 2);

        // Revoke the bundler's authorization to manage user's position on Morpho.
        callbackData[3] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 1);

        // Approve the Bundler to trasfer the aTokens.
        callbackData[4] = _aaveV3PermitATokenCall(privateKey, aToken, address(bundler), aTokenBalance, 0);

        // Transfer the aTokens from the user to the bundler (consumes the approval)
        callbackData[5] = _erc20TransferFrom2Call(aToken, aTokenBalance);

        // Withdraw from Aave and transfer them to Morpho.
        callbackData[6] = _aaveV3WithdrawCall(marketParams.collateralToken, address(bundler), collateralSupplied);

        // Supply collateral on Morpho.
        data[0] = _morphoSupplyCollateralCall(marketParams, collateralSupplied, user, callbackData);

        bundler.multicall(SIG_DEADLINE, data);

        vm.stopPrank();
    }

    function _getATokenV3(address asset) internal view returns (address) {
        DataTypes.ReserveData memory reserve = IPool(aaveV3Pool).getReserveData(asset);
        return reserve.aTokenAddress;
    }

    function _aaveV3PermitATokenCall(
        uint256 privateKey,
        address aToken,
        address spender,
        uint256 value,
        uint256 nonce
    ) internal view returns (bytes memory) {
        bytes32 permitTypehash =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IAToken(aToken).DOMAIN_SEPARATOR(),
                keccak256(abi.encode(permitTypehash, vm.addr(privateKey), spender, value, nonce, SIG_DEADLINE))
            )
        );

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        return abi.encodeCall(AaveV3MigrationBundler.aaveV3PermitAToken, (aToken, value, SIG_DEADLINE, sig.v, sig.r, sig.s));
    }

    function _aaveV3RepayCall(address asset, uint256 amount, uint256 interestRateMode) internal pure returns (bytes memory) {
        return abi.encodeCall(AaveV3MigrationBundler.aaveV3Repay, (asset, amount, interestRateMode));
    }

    function _aaveV3WithdrawCall(address asset, address to, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(AaveV3MigrationBundler.aaveV3Withdraw, (asset, to, amount));
    }
}
