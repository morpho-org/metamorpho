// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IBlueBulker} from "./interfaces/IBlueBulker.sol";
import {Market, IBlue} from "@morpho-blue/interfaces/IBlue.sol";

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
        if (blue == address(0)) revert AddressIsZero();

        _BLUE = IBlue(blue);
    }

    /* EXTERNAL */

    function onBlueSupply(uint256, bytes calldata data) external callback(data) {}

    function onBlueSupplyCollateral(uint256, bytes calldata data) external callback(data) {}

    function onBlueRepay(uint256, bytes calldata data) external callback(data) {}

    function onBlueFlashLoan(address, address, uint256, bytes calldata data) external callback(data) {}

    /* PRIVATE */

    /// @dev Approves this contract to manage the position of `msg.sender` via EIP712 `signature`.
    function _setAuthorization(bytes memory data) private {
        (address authorizer, bool isAuthorized, uint256 deadline, IBlue.Signature memory signature) =
            abi.decode(data, (address, bool, uint256, IBlue.Signature));

        _BLUE.setAuthorization(authorizer, address(this), isAuthorized, deadline, signature);
    }

    /// @dev Supplies `amount` of `asset` of `onBehalf` using permit2 in a single tx.
    ///         The supplied amount cannot be used as collateral but is eligible for the peer-to-peer matching.
    function _supply(bytes memory data) private {
        (Market memory market, uint256 amount, address onBehalf, bytes memory callbackData) =
            abi.decode(data, (Market, uint256, address, bytes));
        if (onBehalf == address(this)) revert AddressIsBulker();

        amount = Math.min(amount, ERC20(address(market.borrowableAsset)).balanceOf(address(this)));

        _approveMaxBlue(address(market.borrowableAsset));

        _BLUE.supply(market, amount, onBehalf, callbackData);
    }

    /// @dev Supplies `amount` of `asset` collateral to the pool on behalf of `onBehalf`.
    function _supplyCollateral(bytes memory data) private {
        (Market memory market, uint256 amount, address onBehalf, bytes memory callbackData) =
            abi.decode(data, (Market, uint256, address, bytes));
        if (onBehalf == address(this)) revert AddressIsBulker();

        amount = Math.min(amount, ERC20(address(market.collateralAsset)).balanceOf(address(this)));

        _approveMaxBlue(address(market.collateralAsset));

        _BLUE.supplyCollateral(market, amount, onBehalf, callbackData);
    }

    /// @dev Borrows `amount` of `asset` on behalf of the sender. Sender must have previously approved the bulker as their manager on Morpho.
    function _borrow(bytes memory data) private {
        (Market memory market, uint256 amount, address receiver) = abi.decode(data, (Market, uint256, address));

        _BLUE.borrow(market, amount, msg.sender, receiver);
    }

    /// @dev Repays `amount` of `asset` on behalf of `onBehalf`.
    function _repay(bytes memory data) private {
        (Market memory market, uint256 amount, address onBehalf, bytes memory callbackData) =
            abi.decode(data, (Market, uint256, address, bytes));
        if (onBehalf == address(this)) revert AddressIsBulker();

        amount = Math.min(amount, ERC20(address(market.borrowableAsset)).balanceOf(address(this)));

        _approveMaxBlue(address(market.borrowableAsset));

        _BLUE.repay(market, amount, onBehalf, callbackData);
    }

    /// @dev Withdraws `amount` of `asset` on behalf of `onBehalf`. Sender must have previously approved the bulker as their manager on Morpho.
    function _withdraw(bytes memory data) private {
        (Market memory market, uint256 amount, address receiver) = abi.decode(data, (Market, uint256, address));

        _BLUE.withdraw(market, amount, msg.sender, receiver);
    }

    /// @dev Withdraws `amount` of `asset` on behalf of sender. Sender must have previously approved the bulker as their manager on Morpho.
    function _withdrawCollateral(bytes memory data) private {
        (Market memory market, uint256 amount, address receiver) = abi.decode(data, (Market, uint256, address));

        _BLUE.withdrawCollateral(market, amount, msg.sender, receiver);
    }

    /// @dev Triggers a flash loan on Blue.
    function _blueFlashLoan(bytes memory data) private {
        (address asset, uint256 amount, bytes memory callbackData) = abi.decode(data, (address, uint256, bytes));

        _approveMaxBlue(asset);

        _BLUE.flashLoan(this, asset, amount, callbackData);
    }

    /// @dev Gives the max approval to the Morpho contract to spend the given `asset` if not already approved.
    function _approveMaxBlue(address asset) private {
        if (ERC20(asset).allowance(address(this), address(_BLUE)) == 0) {
            ERC20(asset).safeApprove(address(_BLUE), type(uint256).max);
        }
    }
}
