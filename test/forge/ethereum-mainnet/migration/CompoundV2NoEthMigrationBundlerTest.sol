// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ICEth} from "contracts/bundlers/migration/interfaces/ICEth.sol";
import {ICToken} from "contracts/bundlers/migration/interfaces/ICToken.sol";
import {IComptroller} from "contracts/bundlers/migration/interfaces/IComptroller.sol";

import "./BaseMigrationTest.sol";
import {CompoundV2MigrationBundler} from "contracts/bundlers/migration/CompoundV2MigrationBundler.sol";

contract CompoundV2NoEthMigrationBundler is BaseMigrationTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    CompoundV2MigrationBundler bundler;

    mapping(address => address) _cTokens;

    address collateralCToken;
    address borrowableCToken;

    uint256 collateralSupplied = 10 ether;
    uint256 borrowed = 1e6;

    function setUp() public override {
        super.setUp();

        _initMarket(DAI, USDC);

        vm.label(C_ETH_V2, "cETHv2");
        _cTokens[WETH] = C_ETH_V2;
        vm.label(C_DAI_V2, "cDAIv2");
        _cTokens[DAI] = C_DAI_V2;
        vm.label(C_USDC_V2, "cUSDCv2");
        _cTokens[USDC] = C_USDC_V2;

        bundler = new CompoundV2MigrationBundler(address(morpho), WETH, C_ETH_V2);
        vm.label(address(bundler), "Compound V2 Migration Bundler");

        collateralCToken = _getCToken(DAI);
        borrowableCToken = _getCToken(USDC);
    }

    /// forge-config: default.fuzz.runs = 3
    function testMigrateBorrowerWithPermit2(uint256 privateKey) public {
        address user;
        (privateKey, user) = _getUserAndKey(privateKey);

        _provideLiquidity(borrowed);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);
        ERC20(marketParams.collateralToken).safeApprove(collateralCToken, collateralSupplied);
        require(ICToken(collateralCToken).mint(collateralSupplied) == 0, "mint error");
        address[] memory enteredMarkets = new address[](1);
        enteredMarkets[0] = collateralCToken;
        require(IComptroller(COMPTROLLER).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICToken(borrowableCToken).borrow(borrowed) == 0, "borrow error");
        vm.stopPrank();

        uint256 cTokenBalance = ICToken(collateralCToken).balanceOf(user);

        vm.prank(user);
        ERC20(collateralCToken).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bytes[] memory data = new bytes[](1);
        bytes[] memory callbackData = new bytes[](7);

        callbackData[0] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 0);
        callbackData[1] = _morphoBorrowCall(borrowed, address(bundler));
        callbackData[2] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), false, 1);
        callbackData[3] = _compoundV2RepayCall(borrowableCToken, borrowed);
        callbackData[4] = _erc20Approve2Call(privateKey, collateralCToken, uint160(cTokenBalance), address(bundler), 0);
        callbackData[5] = _erc20TransferFrom2Call(collateralCToken, cTokenBalance);
        callbackData[6] = _compoundV2WithdrawCall(collateralCToken, collateralSupplied);
        data[0] = _morphoSupplyCollateralCall(collateralSupplied, user, abi.encode(callbackData));

        vm.prank(user);
        bundler.multicall(SIG_DEADLINE, data);

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(bundler));
    }

    function testMigrateSupplierWithPermit2(uint256 privateKey, uint256 supplied) public {
        address user;
        (privateKey, user) = _getUserAndKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.borrowableToken, user, supplied);

        vm.startPrank(user);
        ERC20(marketParams.borrowableToken).safeApprove(borrowableCToken, supplied);
        require(ICToken(borrowableCToken).mint(supplied) == 0, "mint error");
        vm.stopPrank();

        uint256 cTokenBalance = ICToken(borrowableCToken).balanceOf(user);

        vm.prank(user);
        ERC20(borrowableCToken).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bytes[] memory data = new bytes[](4);

        data[0] = _erc20Approve2Call(privateKey, borrowableCToken, uint160(cTokenBalance), address(bundler), 0);
        data[1] = _erc20TransferFrom2Call(borrowableCToken, cTokenBalance);
        data[2] = _compoundV2WithdrawCall(borrowableCToken, supplied);
        data[3] = _morphoSupplyCall(supplied, user, hex"");

        vm.prank(user);
        bundler.multicall(SIG_DEADLINE, data);

        _assertSupplierPosition(supplied, user, address(bundler));
    }

    function testMigrateSupplierToVaultWithPermit2(uint256 privateKey, uint256 supplied) public {
        address user;
        (privateKey, user) = _getUserAndKey(privateKey);
        supplied = bound(supplied, 100, 100 ether);

        deal(marketParams.borrowableToken, user, supplied);

        vm.startPrank(user);
        ERC20(marketParams.borrowableToken).safeApprove(borrowableCToken, supplied);
        require(ICToken(borrowableCToken).mint(supplied) == 0, "mint error");
        vm.stopPrank();

        uint256 cTokenBalance = ICToken(borrowableCToken).balanceOf(user);

        vm.prank(user);
        ERC20(borrowableCToken).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bytes[] memory data = new bytes[](4);

        data[0] = _erc20Approve2Call(privateKey, borrowableCToken, uint160(cTokenBalance), address(bundler), 0);
        data[1] = _erc20TransferFrom2Call(borrowableCToken, cTokenBalance);
        data[2] = _compoundV2WithdrawCall(borrowableCToken, supplied);
        data[3] = _erc4626DepositCall(address(suppliersVault), supplied, user);

        vm.prank(user);
        bundler.multicall(SIG_DEADLINE, data);

        _assertVaultSupplierPosition(supplied, user, address(bundler));
    }

    function _getCToken(address asset) internal view returns (address) {
        address res = _cTokens[asset];
        require(res != address(0), "unknown compound v2 asset");
        return res;
    }

    function _compoundV2RepayCall(address cToken, uint256 repayAmount) internal pure returns (bytes memory) {
        return abi.encodeCall(CompoundV2MigrationBundler.compoundV2Repay, (cToken, repayAmount));
    }

    function _compoundV2WithdrawCall(address cToken, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(CompoundV2MigrationBundler.compoundV2Redeem, (cToken, amount));
    }
}
