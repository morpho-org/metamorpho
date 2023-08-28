// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseBundler} from "./BaseBundler.sol";
import {ERC20Bundler} from "./ERC20Bundler.sol";

import {IPool} from "@aave/v3-core/interfaces/IPool.sol";
import {IAToken} from "@aave/v3-core/interfaces/IAToken.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {Math} from "@morpho-utils/math/Math.sol";

contract AaveV3Bundler is BaseBundler, ERC20Bundler {
    using SafeTransferLib for ERC20;

    IPool immutable AAVE_V3_POOl;

    constructor(address aaveV3Pool) {
        AAVE_V3_POOl = IPool(aaveV3Pool);
    }

    function aaveV3Supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {
        require(onBehalfOf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        amount = Math.min(amount, ERC20(asset).balanceOf(address(this)));

        _approveMaxAaveV3Pool(asset);

        AAVE_V3_POOl.supply(asset, amount, onBehalfOf, referralCode);
    }

    function aaveV3Borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode) external {
        AAVE_V3_POOl.borrow(asset, amount, interestRateMode, referralCode, _initiator);
    }

    function aaveV3Withdraw(address asset, uint256 amount, address to) external {
        AAVE_V3_POOl.withdraw(asset, amount, to);
    }

    function aaveV3Repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external {
        require(onBehalfOf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        amount = Math.min(amount, ERC20(asset).balanceOf(address(this)));

        _approveMaxAaveV3Pool(asset);

        AAVE_V3_POOl.repay(asset, amount, interestRateMode, onBehalfOf);
    }

    function aaveV3PermitAToken(address aToken, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        IAToken(aToken).permit(_initiator, address(this), value, deadline, v, r, s);
    }

    function _approveMaxAaveV3Pool(address asset) internal {
        if (ERC20(asset).allowance(address(this), address(AAVE_V3_POOl)) == 0) {
            ERC20(asset).safeApprove(address(AAVE_V3_POOl), type(uint256).max);
        }
    }
}
