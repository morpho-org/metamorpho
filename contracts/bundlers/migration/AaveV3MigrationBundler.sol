// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MorphoBundler} from "../MorphoBundler.sol";
import {ERC4626Bundler} from "../ERC4626Bundler.sol";
import {ERC20Bundler} from "../ERC20Bundler.sol";

import {IPool} from "@aave/v3-core/interfaces/IPool.sol";
import {IAToken} from "@aave/v3-core/interfaces/IAToken.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

contract AaveV3MigrationBundler is MorphoBundler, ERC4626Bundler, ERC20Bundler {
    using SafeTransferLib for ERC20;

    IPool immutable AAVE_V3_POOl;

    constructor(address morpho, address aaveV3Pool) MorphoBundler(morpho) {
        AAVE_V3_POOl = IPool(aaveV3Pool);
    }

    function aaveV3Withdraw(address asset, address to, uint256 amount) external {
        AAVE_V3_POOl.withdraw(asset, amount, to);
    }

    function aaveV3Repay(address asset, uint256 amount, uint256 interestRateMode) external {
        _approveMaxAaveV3Pool(asset);

        AAVE_V3_POOl.repay(asset, amount, interestRateMode, _initiator);
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
