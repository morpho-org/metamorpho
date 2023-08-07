// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IBlueBulker} from "./interfaces/IBlueBulker.sol";
import {Market, Signature, IBlue} from "@morpho-blue/interfaces/IBlue.sol";

import {Errors} from "./libraries/Errors.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "./BaseBulker.sol";

/// @title BlueBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
/// @notice Contract allowing to bundle multiple interactions with Blue together.
contract BlueBulker is BaseBulker, IBlueBulker {
    using SafeTransferLib for ERC20;

    /* IMMUTABLES */

    IBlue internal immutable _BLUE;

    /* CONSTRUCTOR */

    constructor(address blue) {
        require(blue != address(0), Errors.ZERO_ADDRESS);

        _BLUE = IBlue(blue);
    }

    /* CALLBACKS */

    function onBlueSupply(uint256, bytes calldata data) external callback(data) {}

    function onBlueSupplyCollateral(uint256, bytes calldata data) external callback(data) {}

    function onBlueRepay(uint256, bytes calldata data) external callback(data) {}

    function onBlueFlashLoan(address, uint256, bytes calldata data) external callback(data) {}

    /* ACTIONS */

    /// @dev Approves this contract to manage the position of `msg.sender` via EIP712 `signature`.
    function blueSetAuthorization(address authorizer, bool isAuthorized, uint256 deadline, Signature calldata signature)
        external
    {
        _BLUE.setAuthorization(authorizer, address(this), isAuthorized, deadline, signature);
    }

    /// @dev Supplies `amount` of `asset` of `onBehalf` using permit2 in a single tx.
    ///         The supplied amount cannot be used as collateral but is eligible for the peer-to-peer matching.
    function blueSupply(Market calldata market, uint256 amount, address onBehalf, bytes calldata data) external {
        require(onBehalf != address(this), Errors.BULKER_ADDRESS);

        amount = Math.min(amount, ERC20(market.borrowableAsset).balanceOf(address(this)));

        _approveMaxBlue(market.borrowableAsset);

        _BLUE.supply(market, amount, onBehalf, data);
    }

    /// @dev Supplies `amount` of `asset` collateral to the pool on behalf of `onBehalf`.
    function blueSupplyCollateral(Market calldata market, uint256 amount, address onBehalf, bytes calldata data)
        external
    {
        require(onBehalf != address(this), Errors.BULKER_ADDRESS);

        amount = Math.min(amount, ERC20(market.collateralAsset).balanceOf(address(this)));

        _approveMaxBlue(market.collateralAsset);

        _BLUE.supplyCollateral(market, amount, onBehalf, data);
    }

    /// @dev Borrows `amount` of `asset` on behalf of the sender. Sender must have previously approved the bulker as their manager on Morpho.
    function blueBorrow(Market calldata market, uint256 amount, address receiver) external {
        _BLUE.borrow(market, amount, msg.sender, receiver);
    }

    /// @dev Repays `amount` of `asset` on behalf of `onBehalf`.
    function blueRepay(Market calldata market, uint256 amount, address onBehalf, bytes calldata data) external {
        require(onBehalf != address(this), Errors.BULKER_ADDRESS);

        amount = Math.min(amount, ERC20(market.borrowableAsset).balanceOf(address(this)));

        _approveMaxBlue(market.borrowableAsset);

        _BLUE.repay(market, amount, onBehalf, data);
    }

    /// @dev Withdraws `amount` of `asset` on behalf of `onBehalf`. Sender must have previously approved the bulker as their manager on Morpho.
    function blueWithdraw(Market calldata market, uint256 amount, address receiver) external {
        _BLUE.withdraw(market, amount, msg.sender, receiver);
    }

    /// @dev Withdraws `amount` of `asset` on behalf of sender. Sender must have previously approved the bulker as their manager on Morpho.
    function blueWithdrawCollateral(Market calldata market, uint256 amount, address receiver) external {
        _BLUE.withdrawCollateral(market, amount, msg.sender, receiver);
    }

    /// @dev Triggers a flash loan on Blue.
    function blueLiquidate(Market calldata market, address borrower, uint256 seized, bytes memory data) external {
        _approveMaxBlue(market.borrowableAsset);

        _BLUE.liquidate(market, borrower, seized, data);
    }

    /// @dev Triggers a flash loan on Blue.
    function blueFlashLoan(address asset, uint256 amount, bytes calldata data) external {
        _approveMaxBlue(asset);

        _BLUE.flashLoan(this, asset, amount, data);
    }

    /* PRIVATE */

    /// @dev Gives the max approval to the Morpho contract to spend the given `asset` if not already approved.
    function _approveMaxBlue(address asset) private {
        if (ERC20(asset).allowance(address(this), address(_BLUE)) == 0) {
            ERC20(asset).safeApprove(address(_BLUE), type(uint256).max);
        }
    }
}
