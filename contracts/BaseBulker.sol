// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IWETH} from "./interfaces/IWETH.sol";
import {IWSTETH} from "./interfaces/IWSTETH.sol";
import {IBlueBulker} from "./interfaces/IBlueBulker.sol";
import {Market, IBlue} from "@morpho-blue/interfaces/IBlue.sol";
import {IAaveFlashLender} from "./interfaces/IAaveFlashLender.sol";
import {IERC3156FlashLender} from "./interfaces/IERC3156FlashLender.sol";
import {IBalancerFlashLender} from "./interfaces/IBalancerFlashLender.sol";
import {IAaveFlashBorrower} from "./interfaces/IAaveFlashBorrower.sol";
import {IERC3156FlashBorrower} from "./interfaces/IERC3156FlashBorrower.sol";
import {IBalancerFlashBorrower} from "./interfaces/IBalancerFlashBorrower.sol";
import {IFlashBorrower} from "@morpho-blue/interfaces/IFlashBorrower.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {Signature} from "@morpho-blue/libraries/AuthorizationLib.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20 as ERC20Permit2, Permit2Lib} from "@permit2/libraries/Permit2Lib.sol";

/// @title BaseBulker.
/// @author Morpho Labs.
/// @custom:contact security@blue.xyz
/// @notice Contract allowing to bundle multiple interactions with Blue together.
abstract contract BaseBulker is
    IBlueBulker,
    IFlashBorrower,
    IAaveFlashBorrower,
    IERC3156FlashBorrower,
    IBalancerFlashBorrower
{
    using SafeTransferLib for ERC20;
    using Permit2Lib for ERC20Permit2;

    /* CONSTANTS */

    /// @dev The address of the WETH contract.
    address internal constant _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev The address of the stETH contract.
    address internal constant _ST_ETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    /// @dev The address of the wstETH contract.
    address internal constant _WST_ETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    address internal constant _AAVE_V2 = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;

    address internal constant _AAVE_V3 = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    address internal constant _MAKER_VAULT = 0x60744434d6339a6B27d73d9Eda62b6F66a0a04FA;

    address internal constant _BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    /* IMMUTABLES */

    IBlue internal immutable _BLUE;

    /* STORAGE */

    /// @dev Keeps track of the bulker's latest batch initiator. Also prevents interacting with the bulker outside of an initiated execution context.
    address internal _initiator;

    /* CONSTRUCTOR */

    constructor(address blue) {
        if (blue == address(0)) revert AddressIsZero();

        _BLUE = IBlue(blue);

        ERC20(_WETH).safeApprove(blue, type(uint256).max);
        ERC20(_ST_ETH).safeApprove(_WST_ETH, type(uint256).max);
        ERC20(_WST_ETH).safeApprove(blue, type(uint256).max);
    }

    /* GUARDS */

    modifier lockInitiator() {
        _initiator = msg.sender;

        _;

        delete _initiator;
    }

    function _checkInitiated() internal view {
        require(_initiator != address(0), "2");
    }

    /* EXTERNAL */

    /// @notice Executes the given batch of actions, with the given input data.
    ///         Those actions, if not performed in the correct order, with the proper action's configuration
    ///         and with the proper inclusion of skim final calls, could leave funds in the Bulker contract.
    /// @param actions The batch of action to execute, one after the other.
    function execute(Action[] memory actions) external payable {
        _execute(actions);
    }

    function onBlueSupply(uint256, bytes calldata data) external {
        if (msg.sender != address(_BLUE)) revert OnlyBlue();

        _decodeExecute(data);
    }

    function onBlueSupplyCollateral(uint256, bytes calldata data) external {
        if (msg.sender != address(_BLUE)) revert OnlyBlue();

        _decodeExecute(data);
    }

    function onBlueRepay(uint256, bytes calldata data) external {
        if (msg.sender != address(_BLUE)) revert OnlyBlue();

        _decodeExecute(data);
    }

    /// @dev Only the WETH contract is allowed to transfer ETH to this contract, without any calldata.
    receive() external payable {
        if (msg.sender != _WETH) revert OnlyWETH();
    }

    /* INTERNAL */

    /// @notice Executes the given batch of actions, with the given input data.
    ///         Those actions, if not performed in the correct order, with the proper action's configuration
    ///         and with the proper inclusion of skim final calls, could leave funds in the Bulker contract.
    /// @param actions The batch of action to execute, one after the other.
    function _execute(Action[] memory actions) internal {
        uint256 nbActions = actions.length;
        for (uint256 i; i < nbActions; ++i) {
            _performAction(actions[i]);
        }
    }

    /// @dev Performs the given action.
    function _performAction(Action memory action) internal {
        if (action.actionType == ActionType.APPROVE2) {
            _approve2(action.data);
        } else if (action.actionType == ActionType.TRANSFER_FROM2) {
            _transferFrom2(action.data);
        } else if (action.actionType == ActionType.SET_APPROVAL) {
            _setAuthorization(action.data);
        } else if (action.actionType == ActionType.SUPPLY) {
            _supply(action.data);
        } else if (action.actionType == ActionType.SUPPLY_COLLATERAL) {
            _supplyCollateral(action.data);
        } else if (action.actionType == ActionType.BORROW) {
            _borrow(action.data);
        } else if (action.actionType == ActionType.REPAY) {
            _repay(action.data);
        } else if (action.actionType == ActionType.WITHDRAW) {
            _withdraw(action.data);
        } else if (action.actionType == ActionType.WITHDRAW_COLLATERAL) {
            _withdrawCollateral(action.data);
        } else if (action.actionType == ActionType.WRAP_ETH) {
            _wrapEth(action.data);
        } else if (action.actionType == ActionType.UNWRAP_ETH) {
            _unwrapEth(action.data);
        } else if (action.actionType == ActionType.WRAP_ST_ETH) {
            _wrapStEth(action.data);
        } else if (action.actionType == ActionType.UNWRAP_ST_ETH) {
            _unwrapStEth(action.data);
        } else if (action.actionType == ActionType.SKIM) {
            _skim(action.data);
        } else if (action.actionType == ActionType.BLUE_FLASH_LOAN) {
            _aaveFlashLoan(_AAVE_V2, action.data);
        } else if (action.actionType == ActionType.AAVE_V2_FLASH_LOAN) {
            _aaveFlashLoan(_AAVE_V2, action.data);
        } else if (action.actionType == ActionType.AAVE_V3_FLASH_LOAN) {
            _aaveFlashLoan(_AAVE_V3, action.data);
        } else if (action.actionType == ActionType.MAKER_FLASH_LOAN) {
            _makerFlashLoan(action.data);
        } else if (action.actionType == ActionType.BALANCER_FLASH_LOAN) {
            _balancerFlashLoan(action.data);
        } else {
            revert UnsupportedAction(action.actionType);
        }
    }

    /// @notice Decodes and executes actions encoded as parameter.
    function _decodeExecute(bytes calldata data) internal {
        Action[] memory actions = _decodeActions(data);

        _execute(actions);
    }

    /* PRIVATE */

    /// @notice Decodes the data passed as parameter as an array of actions.
    function _decodeActions(bytes calldata data) private pure returns (Action[] memory) {
        return abi.decode(data, (Action[]));
    }

    /// @dev Approves the given `amount` of `asset` from sender to be spent by this contract via Permit2 with the given `deadline` & EIP712 `signature`.
    function _approve2(bytes memory data) private {
        (address asset, uint256 amount, uint256 deadline, Signature memory signature) =
            abi.decode(data, (address, uint256, uint256, Signature));
        if (amount == 0) revert AmountIsZero();

        ERC20Permit2(asset).simplePermit2(
            msg.sender, address(this), amount, deadline, signature.v, signature.r, signature.s
        );
    }

    /// @dev Transfers the given `amount` of `asset` from sender to this contract via ERC20 transfer with Permit2 fallback.
    function _transferFrom2(bytes memory data) private {
        (address asset, uint256 amount) = abi.decode(data, (address, uint256));
        if (amount == 0) revert AmountIsZero();

        ERC20Permit2(asset).transferFrom2(msg.sender, address(this), amount);
    }

    /// @dev Approves this contract to manage the position of `msg.sender` via EIP712 `signature`.
    function _setAuthorization(bytes memory data) private {
        (address authorizer, bool isAuthorized, uint256 deadline, Signature memory signature) =
            abi.decode(data, (address, bool, uint256, Signature));

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

    /// @dev Wraps the given input of ETH to WETH.
    function _wrapEth(bytes memory data) private {
        (uint256 amount) = abi.decode(data, (uint256));

        amount = Math.min(amount, address(this).balance);
        if (amount == 0) revert AmountIsZero();

        IWETH(_WETH).deposit{value: amount}();
    }

    /// @dev Unwraps the given input of WETH to ETH.
    function _unwrapEth(bytes memory data) private {
        (uint256 amount, address receiver) = abi.decode(data, (uint256, address));
        if (receiver == address(this)) revert AddressIsBulker();
        if (receiver == address(0)) revert AddressIsZero();

        amount = Math.min(amount, ERC20(_WETH).balanceOf(address(this)));
        if (amount == 0) revert AmountIsZero();

        IWETH(_WETH).withdraw(amount);

        SafeTransferLib.safeTransferETH(receiver, amount);
    }

    /// @dev Wraps the given input of stETH to wstETH.
    function _wrapStEth(bytes memory data) private {
        (uint256 amount) = abi.decode(data, (uint256));

        amount = Math.min(amount, ERC20(_ST_ETH).balanceOf(address(this)));
        if (amount == 0) revert AmountIsZero();

        IWSTETH(_WST_ETH).wrap(amount);
    }

    /// @dev Unwraps the given input of wstETH to stETH.
    function _unwrapStEth(bytes memory data) private {
        (uint256 amount, address receiver) = abi.decode(data, (uint256, address));
        if (receiver == address(this)) revert AddressIsBulker();
        if (receiver == address(0)) revert AddressIsZero();

        amount = Math.min(amount, ERC20(_WST_ETH).balanceOf(address(this)));
        if (amount == 0) revert AmountIsZero();

        uint256 unwrapped = IWSTETH(_WST_ETH).unwrap(amount);

        ERC20(_ST_ETH).safeTransfer(receiver, unwrapped);
    }

    /// @dev Sends any ERC20 in this contract to the receiver.
    function _skim(bytes memory data) private {
        (address asset, address receiver) = abi.decode(data, (address, address));
        if (receiver == address(this)) revert AddressIsBulker();
        if (receiver == address(0)) revert AddressIsZero();

        uint256 balance = ERC20(asset).balanceOf(address(this));
        ERC20(asset).safeTransfer(receiver, balance);
    }

    /// @dev Triggers a flash loan on Blue.
    function _blueFlashLoan(bytes memory data) private {
        (address asset, uint256 amount, bytes memory callbackData) = abi.decode(data, (address, uint256, bytes));

        _BLUE.flashLoan(this, asset, amount, callbackData);
    }

    /// @dev Triggers a flash loan on Aave.
    function _aaveFlashLoan(address aave, bytes memory data) private {
        (address[] memory assets, uint256[] memory amounts, bytes memory callbackData) =
            abi.decode(data, (address[], uint256[], bytes));

        IAaveFlashLender(aave).flashLoan(
            address(this), assets, amounts, new uint256[](assets.length), address(this), callbackData, 0
        );
    }

    /// @dev Triggers a flash loan on Maker.
    function _makerFlashLoan(bytes memory data) private {
        (address asset, uint256 amount, bytes memory callbackData) = abi.decode(data, (address, uint256, bytes));

        IERC3156FlashLender(_MAKER_VAULT).flashLoan(address(this), asset, amount, callbackData);
    }

    /// @dev Triggers a flash loan on AaveV3.
    function _balancerFlashLoan(bytes memory data) private {
        (address[] memory assets, uint256[] memory amounts, bytes memory callbackData) =
            abi.decode(data, (address[], uint256[], bytes));

        IBalancerFlashLender(_BALANCER_VAULT).flashLoan(address(this), assets, amounts, callbackData);
    }

    /// @dev Gives the max approval to the Morpho contract to spend the given `asset` if not already approved.
    function _approveMaxBlue(address asset) private {
        if (ERC20(asset).allowance(address(this), address(_BLUE)) == 0) {
            ERC20(asset).safeApprove(address(_BLUE), type(uint256).max);
        }
    }
}
