// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ICEth} from "contracts/bundlers/migration/interfaces/ICEth.sol";
import {ICToken} from "contracts/bundlers/migration/interfaces/ICToken.sol";
import {IComptroller} from "contracts/bundlers/migration/interfaces/IComptroller.sol";

import "./BaseMigrationTest.sol";
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
    uint256 borrowed = 1 ether;

    function setUp() public override {
        super.setUp();

        _initMarket(WETH, DAI);

        vm.label(C_ETH_V2, "cETHv2");
        _cTokens[WETH] = C_ETH_V2;
        vm.label(C_DAI_V2, "cDAIv2");
        _cTokens[DAI] = C_DAI_V2;
        vm.label(C_USDC_V2, "cUSDCv2");
        _cTokens[USDC] = C_USDC_V2;

        bundler = new CompoundV2MigrationBundler(address(morpho), WETH, C_ETH_V2);
        vm.label(address(bundler), "Compound V2 Migration Bundler");

        borrowableCToken = _getCToken(DAI);
    }

    /// forge-config: default.fuzz.runs = 3
    function testMigrateBorrowerWithPermit2(uint256 privateKey) public {
        address user;
        (privateKey, user) = _getUserAndKey(privateKey);

        _provideLiquidity(borrowed);

        deal(user, collateralSupplied);

        vm.startPrank(user);
        ICEth(C_ETH_V2).mint{value: collateralSupplied}();
        address[] memory enteredMarkets = new address[](1);
        enteredMarkets[0] = C_ETH_V2;
        require(IComptroller(COMPTROLLER).enterMarkets(enteredMarkets)[0] == 0, "enter market error");
        require(ICToken(borrowableCToken).borrow(borrowed) == 0, "borrow error");
        vm.stopPrank();

        uint256 cTokenBalance = ICEth(C_ETH_V2).balanceOf(user);

        vm.prank(user);
        ERC20(C_ETH_V2).safeApprove(address(Permit2Lib.PERMIT2), cTokenBalance);

        bytes[] memory data = new bytes[](1);
        bytes[] memory callbackData = new bytes[](7);

        callbackData[0] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 0);
        callbackData[1] = _morphoBorrowCall(borrowed, address(bundler));
        callbackData[2] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), false, 1);
        callbackData[3] = _compoundV2RepayCall(borrowableCToken, borrowed);
        callbackData[4] = _erc20Approve2Call(privateKey, C_ETH_V2, uint160(cTokenBalance), address(bundler), 0);
        callbackData[5] = _erc20TransferFrom2Call(C_ETH_V2, cTokenBalance);
        callbackData[6] = _compoundV2WithdrawCall(C_ETH_V2, collateralSupplied);
        data[0] = _morphoSupplyCollateralCall(collateralSupplied, user, abi.encode(callbackData));

        vm.prank(user);
        bundler.multicall(SIG_DEADLINE, data);

        _assertBorrowerPosition(collateralSupplied, borrowed, user, address(bundler));
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
