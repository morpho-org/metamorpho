// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MorphoBundler} from "../MorphoBundler.sol";
import {ERC4626Bundler} from "../ERC4626Bundler.sol";
import {ERC20Bundler} from "../ERC20Bundler.sol";

import {IWNative} from "../interfaces/IWNative.sol";
import {ICToken} from "./interfaces/ICToken.sol";
import {ICEth} from "./interfaces/ICEth.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

contract CompoundV2MigrationBundler is MorphoBundler, ERC4626Bundler, ERC20Bundler {
    using SafeTransferLib for ERC20;

    ICEth immutable C_NATIVE;
    IWNative immutable WRAPPED_NATIVE;

    constructor(address morpho, address wNative, address cNative) MorphoBundler(morpho) {
        WRAPPED_NATIVE = IWNative(wNative);
        C_NATIVE = ICEth(cNative);
    }

    function compoundV2Repay(address cToken, uint256 repayAmount) external {
        if (cToken == address(C_NATIVE)) {
            WRAPPED_NATIVE.withdraw(repayAmount);

            // Reverts in case of error.
            C_NATIVE.repayBorrowBehalf{value: repayAmount}(_initiator);
        } else {
            _approveMaxCompoundV2(cToken, ICToken(cToken).underlying());

            // Doesn't revert in case of error.
            uint256 err = ICToken(cToken).repayBorrowBehalf(_initiator, repayAmount);
            require(err == 0, "repay error");
        }
    }

    function compoundV2Redeem(address cToken, uint256 amount) external {
        uint256 err = ICToken(cToken).redeemUnderlying(amount);
        require(err == 0, "redeem error");

        if (cToken == address(C_NATIVE)) WRAPPED_NATIVE.deposit{value: amount}();
    }

    function _approveMaxCompoundV2(address cToken, address asset) internal {
        if (ERC20(asset).allowance(address(this), cToken) == 0) {
            ERC20(asset).safeApprove(cToken, type(uint256).max);
        }
    }

    receive() external payable {
        require(msg.sender == address(WRAPPED_NATIVE) || msg.sender == address(C_NATIVE));
    }
}
