// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseMigrationTest.sol";

import {ICEth} from "contracts/bundlers/migration/interfaces/ICeth.sol";
import {ICToken} from "contracts/bundlers/migration/interfaces/ICToken.sol";
import {IComptroller} from "contracts/bundlers/migration/interfaces/IComptroller.sol";

import {CompoundV2MigrationBundler} from "contracts/bundlers/migration/CompoundV2MigrationBundler.sol";

contract CompoundV2EthCollateralMigrationBundler is BaseMigrationTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    CompoundV2MigrationBundler bundler;

    mapping(address => address) _cTokens;

    address borrowableCToken;

    uint256 collateralSupplied = 10 ether;
    uint256 supplied = 10 ether;
    uint256 borrowed = 1 ether;

    function setUp() public override {
        super.setUp();

        _initMarket(WETH, DAI);

        vm.label(cETHv2, "cETHv2");
        _cTokens[WETH] = cETHv2;
        vm.label(cDAIv2, "cDAIv2");
        _cTokens[DAI] = cDAIv2;
        vm.label(cUSDCv2, "cUSDCv2");
        _cTokens[USDC] = cUSDCv2;

        bundler = new CompoundV2MigrationBundler(address(morpho), WETH, cETHv2);
        vm.label(address(bundler), "Compound V2 Migration Bundler");

        borrowableCToken = _getCToken(DAI);

        // Provide liquidity.
        deal(marketParams.borrowableToken, address(this), borrowed * 10);
        ERC20(marketParams.borrowableToken).safeApprove(address(morpho), type(uint256).max);
        morpho.supply(marketParams, borrowed * 10, 0, address(this), hex"");
    }

    /// forge-config: default.fuzz.runs = 3
    function testMigrateBorrowerWithPermit2(uint256 privateKey) public {
        privateKey = bound(privateKey, 1, type(uint32).max);
        address user = vm.addr(privateKey);
        vm.label(user, "user");

        deal(user, collateralSupplied);

        vm.startPrank(user);

        ICEth(cETHv2).mint{value: collateralSupplied}();
        address[] memory enteredMarkets = new address[](1);
        enteredMarkets[0] = cETHv2;
        require(IComptroller(comptroller).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICToken(borrowableCToken).borrow(borrowed) == 0, "borrow error");
        ERC20(marketParams.collateralToken).safeApprove(cETHv2, 0);

        uint256 cTokenBalance = ICEth(cETHv2).balanceOf(user);

        ERC20(cETHv2).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bytes[] memory data = new bytes[](1);
        bytes[] memory callbackData = new bytes[](7);

        callbackData[0] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 0);
        callbackData[1] = _morphoBorrowCall(borrowed, address(bundler));
        callbackData[2] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), false, 1);
        callbackData[3] = _compoundV2RepayCall(borrowableCToken, borrowed);
        callbackData[4] = _erc20Approve2Call(privateKey, cETHv2, uint160(cTokenBalance), address(bundler), 0);
        callbackData[5] = _erc20TransferFrom2Call(cETHv2, cTokenBalance);
        callbackData[6] = _compoundV2WithdrawCall(cETHv2, collateralSupplied);
        data[0] = _morphoSupplyCollateralCall(collateralSupplied, user, callbackData);

        bundler.multicall(SIG_DEADLINE, data);

        vm.stopPrank();

        assertEq(morpho.collateral(marketParams.id(), user), collateralSupplied);
        assertEq(morpho.expectedBorrowBalance(marketParams, user), borrowed);
        assertFalse(morpho.isAuthorized(user, address(bundler)));
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
