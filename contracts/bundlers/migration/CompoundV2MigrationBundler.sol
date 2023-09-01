// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IWNative} from "../interfaces/IWNative.sol";
import {ICToken} from "./interfaces/ICToken.sol";
import {ICEth} from "./interfaces/ICEth.sol";

import {MigrationBundler} from "./MigrationBundler.sol";
import {ERC20Bundler} from "../ERC20Bundler.sol";

contract CompoundV2MigrationBundler is MigrationBundler, ERC20Bundler {
    ICEth public immutable _NATIVE;
    IWNative public immutable WRAPPED_NATIVE;

    constructor(address morpho, address wNative, address cNative) MigrationBundler(morpho) {
        WRAPPED_NATIVE = IWNative(wNative);
        C_NATIVE = ICEth(cNative);
    }

    function compoundV2Repay(address cToken, uint256 repayAmount) external {
        if (cToken == address(C_NATIVE)) {
            WRAPPED_NATIVE.withdraw(repayAmount);

            // Reverts in case of error.
            C_NATIVE.repayBorrowBehalf{value: repayAmount}(_initiator);
        } else {
            _approveMaxTo(ICToken(cToken).underlying(), cToken);

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

    receive() external payable {
        require(msg.sender == address(WRAPPED_NATIVE) || msg.sender == address(C_NATIVE));
    }
}
