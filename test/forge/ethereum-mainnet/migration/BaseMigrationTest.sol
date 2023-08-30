// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "@permit2/interfaces/IAllowanceTransfer.sol";

import {MorphoBundler} from "contracts/bundlers/MorphoBundler.sol";
import {ERC20Bundler} from "contracts/bundlers/ERC20Bundler.sol";
import {WNativeBundler} from "contracts/bundlers/WNativeBundler.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";
import {MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

import "../../helpers/ForkTest.sol";

contract BaseMigrationTest is ForkTest {
    using MarketParamsLib for MarketParams;

    uint256 internal constant SIG_DEADLINE = type(uint32).max;

    MarketParams marketParams;

    function setUp() public virtual override {
        super.setUp();
    }

    function _initMarket(address collateral, address borrowable) internal {
        marketParams.collateralToken = collateral;
        marketParams.borrowableToken = borrowable;
        marketParams.oracle = address(oracle);
        marketParams.irm = address(irm);
        marketParams.lltv = 0.8 ether;

        (,,,, uint128 lastUpdate,) = morpho.market(marketParams.id());
        if (lastUpdate == 0) {
            morpho.createMarket(marketParams);
        }
    }

    function _getUserAndKey(uint256 privateKey) internal returns (uint256, address) {
        privateKey = bound(privateKey, 1, type(uint32).max);
        address user = vm.addr(privateKey);
        vm.label(user, "user");
        return (privateKey, user);
    }

    function _network() internal pure override returns (string memory) {
        return "ethereum-mainnet";
    }

    function _morphoSetAuthorizationWithSigCall(
        uint256 privateKey,
        address authorized,
        bool isAuthorized,
        uint256 nonce
    ) internal view returns (bytes memory) {
        Authorization memory auth = Authorization({
            authorizer: vm.addr(privateKey),
            authorized: authorized,
            isAuthorized: isAuthorized,
            nonce: nonce,
            deadline: SIG_DEADLINE
        });

        bytes32 authorizationTypehash = keccak256(
            "Authorization(address authorizer,address authorized,bool isAuthorized,uint256 nonce,uint256 deadline)"
        );
        bytes32 digest =
            ECDSA.toTypedDataHash(morpho.DOMAIN_SEPARATOR(), keccak256(abi.encode(authorizationTypehash, auth)));

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        return abi.encodeCall(MorphoBundler.morphoSetAuthorizationWithSig, (auth, sig));
    }

    function _morphoBorrowCall(uint256 amount, address receiver) internal view returns (bytes memory) {
        return abi.encodeCall(MorphoBundler.morphoBorrow, (marketParams, amount, 0, receiver));
    }

    function _morphoSupplyCollateralCall(uint256 amount, address onBehalf, bytes[] memory callbackData)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeCall(
            MorphoBundler.morphoSupplyCollateral, (marketParams, amount, onBehalf, abi.encode(callbackData))
        );
    }

    function _erc20TransferFrom2Call(address asset, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(ERC20Bundler.transferFrom2, (asset, amount));
    }

    function _erc20Approve2Call(uint256 privateKey, address asset, uint160 amount, address spender, uint48 nonce)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = ECDSA.toTypedDataHash(
            Permit2Lib.PERMIT2.DOMAIN_SEPARATOR(),
            PermitHash.hash(
                IAllowanceTransfer.PermitSingle({
                    details: IAllowanceTransfer.PermitDetails({
                        token: asset,
                        amount: amount,
                        expiration: type(uint48).max,
                        nonce: nonce
                    }),
                    spender: spender,
                    sigDeadline: SIG_DEADLINE
                })
            )
        );

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);

        return abi.encodeCall(ERC20Bundler.approve2, (asset, amount, SIG_DEADLINE, sig));
    }

    function _wNativeUnwrapCall(uint256 amount, address receiver) internal pure returns (bytes memory) {
        return abi.encodeCall(WNativeBundler.unwrapNative, (amount, receiver));
    }

    function _wNativeWrapCall(uint256 amount, address receiver) internal pure returns (bytes memory) {
        return abi.encodeCall(WNativeBundler.wrapNative, (amount, receiver));
    }
}
