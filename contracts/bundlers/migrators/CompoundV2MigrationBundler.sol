// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MorphoBundler} from "../MorphoBundler.sol";
import {ERC4626Bundler} from "../ERC4626Bundler.sol";
import {ERC20Bundler} from "../ERC20Bundler.sol";
import {WNativeBundler} from "../WNativeBundler.sol";

import {ICToken} from "./interfaces/ICToken.sol";
import {ICEth} from "./interfaces/ICEth.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

contract CompoundV3MigrationBundler is MorphoBundler, ERC4626Bundler, ERC20Bundler, WNativeBundler {
    using SafeTransferLib for ERC20;

    ICEth immutable C_NATIVE;

    constructor(address morpho, address wNative, address cNative) MorphoBundler(morpho) WNativeBundler(wNative) {
        C_NATIVE = ICEth(cNative);
    }

    function compoundV3RepayAll(address cToken) external {
        if (cToken == address(C_NATIVE)) {
            C_NATIVE.repayBorrowBehalf{value: address(this).balance}(_initiator);
        } else {
            _approveMaxCompoundV2(cToken, ICToken(cToken).underlying());
            ICToken(cToken).repayBorrowBehalf(_initiator, type(uint256).max);
        }
    }

    function compoundV3Redeem(address cToken, uint256 amount) external {
        ICToken(cToken).redeem(amount);
    }

    function _approveMaxCompoundV2(address cToken, address asset) internal {
        if (ERC20(asset).allowance(address(this), cToken) == 0) {
            ERC20(asset).safeApprove(cToken, type(uint256).max);
        }
    }
}
