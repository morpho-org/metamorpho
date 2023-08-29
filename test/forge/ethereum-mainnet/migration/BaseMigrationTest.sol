// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MorphoBundler} from "contracts/bundlers/MorphoBundler.sol";
import {ERC20Bundler} from "contracts/bundlers/ERC20Bundler.sol";
import "../../helpers/ForkTest.sol";

contract BaseMigrationTest is ForkTest {
    uint256 constant internal SIG_DEADLINE = type(uint32).max;

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

        bytes32 authorizationTypehash =
            keccak256("Authorization(address authorizer,address authorized,bool isAuthorized,uint256 nonce,uint256 deadline)");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                morpho.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(authorizationTypehash, auth))
            )
        );

        Signature memory sig;
        (sig.v, sig.r, sig.s) = vm.sign(privateKey, digest);
        return abi.encodeCall(
            MorphoBundler.morphoSetAuthorizationWithSig, (auth, sig)
        );
    }

    function _morphoBorrowCall(MarketParams memory marketParams, uint256 amount, address receiver) internal pure returns (bytes memory) {
        return abi.encodeCall(
            MorphoBundler.morphoBorrow, (marketParams, amount, 0, receiver)
        );
    }

    function _morphoSupplyCollateralCall(MarketParams memory marketParams, uint256 amount, address onBehalf, bytes[] memory callbackData) internal pure returns (bytes memory) {
        return abi.encodeCall(
            MorphoBundler.morphoSupplyCollateral, (marketParams, amount, onBehalf, abi.encode(callbackData))
        );
    }

    function _erc20TransferFrom2Call(address token, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeCall(
            ERC20Bundler.transferFrom2, (token, amount)
        );
    }
}
