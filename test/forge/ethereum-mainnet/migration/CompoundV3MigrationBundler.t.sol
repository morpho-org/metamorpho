// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseMigrationTest.sol";

import {ICompoundV3} from "contracts/bundlers/migration/interfaces/ICompoundV3.sol";

import {CompoundV3MigrationBundler} from "contracts/bundlers/migration/CompoundV3MigrationBundler.sol";

contract CompoundV3MigrationBundlerTest is BaseMigrationTest {
    using SafeTransferLib for ERC20;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;

    CompoundV3MigrationBundler bundler;

    ICompoundV3 cToken;

    mapping(address => address) _cTokens;

    uint256 collateralSupplied = 10 ether;
    uint256 supplied = 10 ether;
    uint256 borrowed = 1 ether;

    function setUp() public override {
        super.setUp();

        _initMarket(CB_ETH, WETH);

        vm.label(C_WETH_V3, "cWETHv3");
        _cTokens[WETH] = C_WETH_V3;

        vm.label(address(bundler), "Compound V3 Migration Bundler");
        cToken = ICompoundV3(_getCTokenV3(marketParams.borrowableToken));

        bundler = new CompoundV3MigrationBundler(address(morpho));

        // Provide liquidity.
        deal(marketParams.borrowableToken, address(this), borrowed * 10);
        ERC20(marketParams.borrowableToken).safeApprove(address(morpho), type(uint256).max);
        morpho.supply(marketParams, borrowed * 10, 0, address(this), hex"");
    }

    /// forge-config: default.fuzz.runs = 3
    function testMigrateBorrowerWithCompoundAllowance(uint256 privateKey) public {
        address user;
        (privateKey, user) = _getUserAndKey(privateKey);

        deal(marketParams.collateralToken, user, collateralSupplied);

        vm.startPrank(user);

        ERC20(marketParams.collateralToken).safeApprove(address(cToken), type(uint256).max);
        cToken.supply(marketParams.collateralToken, collateralSupplied);
        cToken.withdraw(marketParams.borrowableToken, borrowed);
        ERC20(marketParams.collateralToken).safeApprove(address(cToken), 0);

        bytes[] memory data = new bytes[](1);
        bytes[] memory callbackData = new bytes[](7);

        callbackData[0] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), true, 0);
        callbackData[1] = _morphoBorrowCall(borrowed, address(bundler));
        callbackData[2] = _morphoSetAuthorizationWithSigCall(privateKey, address(bundler), false, 1);
        callbackData[3] = _compoundV3RepayCall(address(cToken), marketParams.borrowableToken, borrowed);
        callbackData[4] = _compoundV3AllowCall(privateKey, address(cToken), address(bundler), true, 0);
        callbackData[5] =
            _compoundV3WithdrawCall(address(cToken), address(bundler), marketParams.collateralToken, collateralSupplied);
        callbackData[6] = _compoundV3AllowCall(privateKey, address(cToken), address(bundler), false, 1);
        data[0] = _morphoSupplyCollateralCall(collateralSupplied, user, callbackData);

        bundler.multicall(SIG_DEADLINE, data);

        vm.stopPrank();

        assertEq(morpho.collateral(marketParams.id(), user), collateralSupplied);
        assertEq(morpho.expectedBorrowBalance(marketParams, user), borrowed);
        assertFalse(morpho.isAuthorized(user, address(bundler)));
    }

    function _getCTokenV3(address asset) internal view returns (address) {
        address result = _cTokens[asset];
        require(result != address(0), "unknown compound v3 market");
        return result;
    }

    function _compoundV3AllowCall(uint256 privateKey, address instance, address manager, bool isAllowed, uint256 nonce)
        internal
        view
        returns (bytes memory)
    {
        bytes32 permitTypehash =
            keccak256("Authorization(address owner,address manager,bool isAllowed,uint256 nonce,uint256 expiry)");
        bytes32 domainTypehash =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 domainSeparator = keccak256(
            abi.encode(
                domainTypehash,
                keccak256(bytes(ICompoundV3(instance).name())),
                keccak256(bytes(ICompoundV3(instance).version())),
                block.chainid,
                instance
            )
        );
        bytes32 digest = ECDSA.toTypedDataHash(
            domainSeparator,
            keccak256(abi.encode(permitTypehash, vm.addr(privateKey), manager, isAllowed, nonce, SIG_DEADLINE))
        );

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        return abi.encodeCall(
            CompoundV3MigrationBundler.compoundV3AllowBySig,
            (instance, isAllowed, nonce, SIG_DEADLINE, sig.v, sig.r, sig.s)
        );
    }

    function _compoundV3RepayCall(address instance, address asset, uint256 amount)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(CompoundV3MigrationBundler.compoundV3Supply, (instance, asset, amount));
    }

    function _compoundV3WithdrawCall(address instance, address to, address asset, uint256 amount)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(CompoundV3MigrationBundler.compoundV3Withdraw, (instance, to, asset, amount));
    }
}
