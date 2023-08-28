// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseBundler} from "./BaseBundler.sol";
import {ERC20Bundler} from "./ERC20Bundler.sol";

import {IMorpho} from "@morpho-aave-v3/interfaces/IMorpho.sol";

import {Types} from "@morpho-aave-v3/libraries/Types.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {Math} from "@morpho-utils/math/Math.sol";

contract AaveV3OptimizerBundler is BaseBundler, ERC20Bundler {
    using SafeTransferLib for ERC20;

    IMorpho immutable AAVE_V3_OPTIMIZER;

    constructor(address aaveV3Optimizer) {
        AAVE_V3_OPTIMIZER = IMorpho(aaveV3Optimizer);
    }

    function aaveV3OptimizerSupply(address underlying, uint256 amount, address onBehalf, uint256 maxIterations)
        external
    {
        require(onBehalf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        amount = Math.min(amount, ERC20(underlying).balanceOf(address(this)));

        _approveMaxAaveV3Optimizer(underlying);

        AAVE_V3_OPTIMIZER.supply(underlying, amount, onBehalf, maxIterations);
    }

    function aaveV3OptimizerSupplyCollateral(address underlying, uint256 amount, address onBehalf) external {
        require(onBehalf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        amount = Math.min(amount, ERC20(underlying).balanceOf(address(this)));

        _approveMaxAaveV3Optimizer(underlying);

        AAVE_V3_OPTIMIZER.supplyCollateral(underlying, amount, onBehalf);
    }

    function aaveV3OptimizerBorrow(
        address underlying,
        uint256 amount,
        address onBehalf,
        address receiver,
        uint256 maxIterations
    ) external {
        require(onBehalf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        AAVE_V3_OPTIMIZER.borrow(underlying, amount, onBehalf, receiver, maxIterations);
    }

    function aaveV3OptimizerRepay(address underlying, uint256 amount, address onBehalf) external {
        require(onBehalf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        amount = Math.min(amount, ERC20(underlying).balanceOf(address(this)));

        _approveMaxAaveV3Optimizer(underlying);

        AAVE_V3_OPTIMIZER.repay(underlying, amount, onBehalf);
    }

    function aaveV3OptimizerWithdraw(
        address underlying,
        uint256 amount,
        address onBehalf,
        address receiver,
        uint256 maxIterations
    ) external {
        require(onBehalf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        AAVE_V3_OPTIMIZER.withdraw(underlying, amount, onBehalf, receiver, maxIterations);
    }

    function aaveV3OptimizerApproveManagerWithSig(
        address delegator,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 deadline,
        Types.Signature calldata signature
    ) external {
        AAVE_V3_OPTIMIZER.approveManagerWithSig(delegator, manager, isAllowed, nonce, deadline, signature);
    }

    function _approveMaxAaveV3Optimizer(address asset) internal {
        if (ERC20(asset).allowance(address(this), address(AAVE_V3_OPTIMIZER)) == 0) {
            ERC20(asset).safeApprove(address(AAVE_V3_OPTIMIZER), type(uint256).max);
        }
    }
}
