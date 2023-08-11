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
abstract contract BlueBulker is BaseBulker, IBlueBulker {
    using SafeTransferLib for ERC20;

    /* IMMUTABLES */

    IBlue public immutable BLUE;

    /* CONSTRUCTOR */

    constructor(address blue) {
        require(blue != address(0), Errors.ZERO_ADDRESS);

        BLUE = IBlue(blue);
    }

    /* MODIFIERS */

    modifier callback(bytes calldata data) {
        _checkInitiated();

        _multicall(abi.decode(data, (bytes[])));

        _;
    }

    /* CALLBACKS */

    function onBlueSupply(uint256, bytes calldata data) external callback(data) {
        // Don't need to approve Blue to pull tokens because it should already be approved max.
    }

    function onBlueSupplyCollateral(uint256, bytes calldata data) external callback(data) {
        // Don't need to approve Blue to pull tokens because it should already be approved max.
    }

    function onBlueRepay(uint256, bytes calldata data) external callback(data) {
        // Don't need to approve Blue to pull tokens because it should already be approved max.
    }

    function onBlueFlashLoan(uint256, bytes calldata data) external callback(data) {
        // Don't need to approve Blue to pull tokens because it should already be approved max.
    }

    /* ACTIONS */

    /// @dev Approves this contract to manage the initiator's position via EIP712 `signature`.
    function blueSetAuthorization(address authorizer, bool isAuthorized, uint256 deadline, Signature calldata signature)
        external
    {
        BLUE.setAuthorizationWithSig(authorizer, address(this), isAuthorized, deadline, signature);
    }

    /// @dev Supplies `amount` of `asset` of `onBehalf` using permit2 in a single tx.
    ///      The supplied amount cannot be used as collateral but is eligible to earn interest.
    ///      Note: pass `amount = type(uint256).max` to supply the bulker's borrowable asset balance.
    function blueSupply(Market calldata market, uint256 amount, uint256 shares, address onBehalf, bytes calldata data)
        external
    {
        require(onBehalf != address(this), Errors.BULKER_ADDRESS);

        // Don't always cap the amount to the bulker's balance because the liquidity can be transferred inside the supply callback.
        if (amount == type(uint256).max) amount = ERC20(market.borrowableAsset).balanceOf(address(this));

        _approveMaxBlue(market.borrowableAsset);

        BLUE.supply(market, amount, shares, onBehalf, data);
    }

    /// @dev Supplies `amount` of `asset` collateral to the pool on behalf of `onBehalf`.
    ///      Note: pass `amount = type(uint256).max` to supply the bulker's collateral asset balance.
    function blueSupplyCollateral(Market calldata market, uint256 amount, address onBehalf, bytes calldata data)
        external
    {
        require(onBehalf != address(this), Errors.BULKER_ADDRESS);

        // Don't always cap the amount to the bulker's balance because the liquidity can be transferred inside the supply collateral callback.
        if (amount == type(uint256).max) amount = ERC20(market.collateralAsset).balanceOf(address(this));

        _approveMaxBlue(market.collateralAsset);

        BLUE.supplyCollateral(market, amount, onBehalf, data);
    }

    /// @dev Borrows `amount` of `asset` on behalf of the sender. Sender must have previously approved the bulker as their manager on Blue.
    function blueBorrow(Market calldata market, uint256 amount, uint256 shares, address receiver) external {
        BLUE.borrow(market, amount, shares, _initiator, receiver);
    }

    /// @dev Repays `amount` of `asset` on behalf of `onBehalf`.
    ///      Note: pass `amount = type(uint256).max` to repay the bulker's borrowable asset balance.
    function blueRepay(Market calldata market, uint256 amount, uint256 shares, address onBehalf, bytes calldata data)
        external
    {
        require(onBehalf != address(this), Errors.BULKER_ADDRESS);

        // Don't always cap the amount to the bulker's balance because the liquidity can be transferred inside the repay callback.
        if (amount == type(uint256).max) amount = ERC20(market.borrowableAsset).balanceOf(address(this));

        _approveMaxBlue(market.borrowableAsset);

        BLUE.repay(market, amount, shares, onBehalf, data);
    }

    /// @dev Withdraws `amount` of the borrowable asset on behalf of `onBehalf`. Sender must have previously authorized the bulker to act on their behalf on Blue.
    function blueWithdraw(Market calldata market, uint256 amount, uint256 shares, address receiver) external {
        BLUE.withdraw(market, amount, shares, _initiator, receiver);
    }

    /// @dev Withdraws `amount` of the collateral asset on behalf of sender. Sender must have previously authorized the bulker to act on their behalf on Blue.
    function blueWithdrawCollateral(Market calldata market, uint256 amount, address receiver) external {
        BLUE.withdrawCollateral(market, amount, _initiator, receiver);
    }

    /// @dev Triggers a liquidation on Blue.
    function blueLiquidate(Market calldata market, address borrower, uint256 seized, bytes memory data) external {
        _approveMaxBlue(market.borrowableAsset);

        BLUE.liquidate(market, borrower, seized, data);
    }

    /// @dev Triggers a flash loan on Blue.
    function blueFlashLoan(address asset, uint256 amount, bytes calldata data) external {
        _approveMaxBlue(asset);

        BLUE.flashLoan(asset, amount, data);
    }

    /* PRIVATE */

    /// @dev Gives the max approval to the Blue contract to spend the given `asset` if not already approved.
    function _approveMaxBlue(address asset) private {
        if (ERC20(asset).allowance(address(this), address(BLUE)) == 0) {
            ERC20(asset).safeApprove(address(BLUE), type(uint256).max);
        }
    }
}
