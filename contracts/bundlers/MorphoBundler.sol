// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IMorphoBundler} from "./interfaces/IMorphoBundler.sol";
import {MarketParams, Signature, Authorization, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {SafeTransferLib, ERC20} from "solmate/src/utils/SafeTransferLib.sol";

import {BaseBundler} from "./BaseBundler.sol";

/// @title MorphoBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Bundler contract managing interactions with Morpho.
abstract contract MorphoBundler is BaseBundler, IMorphoBundler {
    using SafeTransferLib for ERC20;

    /* IMMUTABLES */

    /// @notice The Morpho contract address.
    IMorpho public immutable MORPHO;

    /* CONSTRUCTOR */

    constructor(address morpho) {
        require(morpho != address(0), ErrorsLib.ZERO_ADDRESS);

        MORPHO = IMorpho(morpho);
    }

    /* CALLBACKS */

    function onMorphoSupply(uint256, bytes calldata data) external {
        // Don't need to approve Blue to pull tokens because it should already be approved max.
        _callback(data);
    }

    function onMorphoSupplyCollateral(uint256, bytes calldata data) external {
        // Don't need to approve Blue to pull tokens because it should already be approved max.
        _callback(data);
    }

    function onMorphoRepay(uint256, bytes calldata data) external {
        // Don't need to approve Blue to pull tokens because it should already be approved max.
        _callback(data);
    }

    function onMorphoFlashLoan(uint256, bytes calldata data) external {
        // Don't need to approve Blue to pull tokens because it should already be approved max.
        _callback(data);
    }

    /* ACTIONS */

    /// @dev Approves this contract to manage the `authorization.authorizer`'s position via EIP712 `signature`.
    function morphoSetAuthorizationWithSig(Authorization calldata authorization, Signature calldata signature)
        external
        payable
    {
        MORPHO.setAuthorizationWithSig(authorization, signature);
    }

    /// @dev Supplies `amount` of `asset` of `onBehalf` using permit2 in a single tx.
    ///      The supplied amount cannot be used as collateral but is eligible to earn interest.
    ///      Note: pass `amount = type(uint256).max` to supply the bundler's borrowable asset balance.
    function morphoSupply(
        MarketParams calldata marketparams,
        uint256 amount,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external payable {
        require(onBehalf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        // Don't always cap the amount to the bundler's balance because the liquidity can be transferred later
        // (via the `onMorphoSupply` callback).
        if (amount == type(uint256).max) amount = ERC20(marketparams.borrowableToken).balanceOf(address(this));

        _approveMaxBlue(marketparams.borrowableToken);

        MORPHO.supply(marketparams, amount, shares, onBehalf, data);
    }

    /// @dev Supplies `amount` of `asset` collateral to the pool on behalf of `onBehalf`.
    ///      Note: pass `amount = type(uint256).max` to supply the bundler's collateral asset balance.
    function morphoSupplyCollateral(
        MarketParams calldata marketparams,
        uint256 amount,
        address onBehalf,
        bytes calldata data
    ) external payable {
        require(onBehalf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        // Don't always cap the amount to the bundler's balance because the liquidity can be transferred later
        // (via the `onMorphoSupplyCollateral` callback).
        if (amount == type(uint256).max) amount = ERC20(marketparams.collateralToken).balanceOf(address(this));

        _approveMaxBlue(marketparams.collateralToken);

        MORPHO.supplyCollateral(marketparams, amount, onBehalf, data);
    }

    /// @dev Borrows `amount` of `asset` on behalf of the sender. Sender must have previously approved the bundler as
    /// their manager on Blue.
    function morphoBorrow(MarketParams calldata marketparams, uint256 amount, uint256 shares, address receiver)
        external
        payable
    {
        MORPHO.borrow(marketparams, amount, shares, _initiator, receiver);
    }

    /// @dev Repays `amount` of `asset` on behalf of `onBehalf`.
    ///      Note: pass `amount = type(uint256).max` to repay the bundler's borrowable asset balance.
    function morphoRepay(
        MarketParams calldata marketparams,
        uint256 amount,
        uint256 shares,
        address onBehalf,
        bytes calldata data
    ) external payable {
        require(onBehalf != address(this), ErrorsLib.BUNDLER_ADDRESS);

        // Don't always cap the amount to the bundler's balance because the liquidity can be transferred later
        // (via the `onMorphoRepay` callback).
        if (amount == type(uint256).max) amount = ERC20(marketparams.borrowableToken).balanceOf(address(this));

        _approveMaxBlue(marketparams.borrowableToken);

        MORPHO.repay(marketparams, amount, shares, onBehalf, data);
    }

    /// @dev Withdraws `amount` of the borrowable asset on behalf of `onBehalf`. Sender must have previously authorized
    /// the bundler to act on their behalf on Blue.
    function morphoWithdraw(MarketParams calldata marketparams, uint256 amount, uint256 shares, address receiver)
        external
        payable
    {
        MORPHO.withdraw(marketparams, amount, shares, _initiator, receiver);
    }

    /// @dev Withdraws `amount` of the collateral asset on behalf of sender. Sender must have previously authorized the
    /// bundler to act on their behalf on Blue.
    function morphoWithdrawCollateral(MarketParams calldata marketparams, uint256 amount, address receiver)
        external
        payable
    {
        MORPHO.withdrawCollateral(marketparams, amount, _initiator, receiver);
    }

    /// @dev Triggers a liquidation on Blue.
    function morphoLiquidate(
        MarketParams calldata marketparams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes memory data
    ) external payable {
        _approveMaxBlue(marketparams.borrowableToken);

        MORPHO.liquidate(marketparams, borrower, seizedAssets, repaidShares, data);
    }

    /// @dev Triggers a flash loan on Blue.
    function morphoFlashLoan(address asset, uint256 amount, bytes calldata data) external payable {
        _approveMaxBlue(asset);

        MORPHO.flashLoan(asset, amount, data);
    }

    /* INTERNAL */

    /// @dev Triggers `_multicall` logic during a callback.
    function _callback(bytes calldata data) internal {
        _checkInitiated();
        _multicall(abi.decode(data, (bytes[])));
    }

    /// @dev Gives the max approval to the Blue contract to spend the given `asset` if not already approved.
    function _approveMaxBlue(address asset) internal {
        if (ERC20(asset).allowance(address(this), address(MORPHO)) == 0) {
            ERC20(asset).safeApprove(address(MORPHO), type(uint256).max);
        }
    }
}
