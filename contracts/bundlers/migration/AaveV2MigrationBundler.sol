// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {EVMBundler} from "../EVMBundler.sol";

import {ILendingPool} from "@morpho-v1/aave-v2/interfaces/aave/ILendingPool.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

contract AaveV2MigrationBundler is EVMBundler {
    using SafeTransferLib for ERC20;

    ILendingPool immutable AAVE_V2_POOl;

    constructor(address morpho, address aaveV2Pool) EVMBundler(morpho) {
        AAVE_V2_POOl = ILendingPool(aaveV2Pool);
    }

    function aaveV2Withdraw(address asset, uint256 amount, address to) external {
        AAVE_V2_POOl.withdraw(asset, amount, to);
    }

    function aaveV2Repay(address asset, uint256 amount, uint256 rateMode) external {
        _approveMaxAaveV2Pool(asset);

        AAVE_V2_POOl.repay(asset, amount, rateMode, _initiator);
    }

    function _approveMaxAaveV2Pool(address asset) internal {
        if (ERC20(asset).allowance(address(this), address(AAVE_V2_POOl)) == 0) {
            ERC20(asset).safeApprove(address(AAVE_V2_POOl), type(uint256).max);
        }
    }
}
