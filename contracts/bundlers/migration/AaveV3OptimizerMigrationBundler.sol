// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MorphoBundler} from "../MorphoBundler.sol";
import {ERC4626Bundler} from "../ERC4626Bundler.sol";

import {IMorpho} from "@morpho-aave-v3/interfaces/IMorpho.sol";

import {Types} from "@morpho-aave-v3/libraries/Types.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

contract AaveV3OptimizerMigrationBundler is MorphoBundler, ERC4626Bundler {
    using SafeTransferLib for ERC20;

    IMorpho immutable AAVE_V3_OPTIMIZER;

    constructor(address morpho, address aaveV3Optimizer) MorphoBundler(morpho) {
        AAVE_V3_OPTIMIZER = IMorpho(aaveV3Optimizer);
    }

    function aaveV3OptimizerRepayAll(address underlying, uint256 amount) external {
        _approveMaxAaveV3Optimizer(underlying);

        AAVE_V3_OPTIMIZER.repay(underlying, amount, _initiator);
    }

    function aaveV3OptimizerWithdrawAll(address underlying, address receiver, uint256 maxIterations) external {
        AAVE_V3_OPTIMIZER.withdraw(underlying, type(uint256).max, _initiator, receiver, maxIterations);
    }

    function aaveV3OptimizerWithdrawAllCollateral(address underlying, address receiver) external {
        AAVE_V3_OPTIMIZER.withdrawCollateral(underlying, type(uint256).max, _initiator, receiver);
    }

    function aaveV3OptimizerApproveManagerWithSig(
        bool isAllowed,
        uint256 nonce,
        uint256 deadline,
        Types.Signature calldata signature
    ) external {
        AAVE_V3_OPTIMIZER.approveManagerWithSig(_initiator, address(this), isAllowed, nonce, deadline, signature);
    }

    function _approveMaxAaveV3Optimizer(address asset) internal {
        if (ERC20(asset).allowance(address(this), address(AAVE_V3_OPTIMIZER)) == 0) {
            ERC20(asset).safeApprove(address(AAVE_V3_OPTIMIZER), type(uint256).max);
        }
    }
}
