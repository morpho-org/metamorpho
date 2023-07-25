// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IBlueBulker {
    /* ERRORS */

    /// @notice Thrown when execution parameters don't have the same length.
    /// @param nbActions The number of input actions.
    /// @param nbData The number of data inputs.
    error InconsistentParameters(uint256 nbActions, uint256 nbData);

    /// @notice Thrown when another address than WETH sends ETH to the contract.
    error OnlyWETH();

    /// @notice Thrown when an address used as parameter is the zero address.
    error AddressIsZero();

    /// @notice Thrown when an address parameter is the bulker's address.
    error AddressIsBulker();

    /// @notice Thrown when an amount used as parameter is zero.
    error AmountIsZero();

    /// @notice Thrown when the action is unsupported.
    error UnsupportedAction(ActionType action);

    /* ENUMS */

    enum ActionType {
        APPROVE2,
        TRANSFER_FROM2,
        SET_APPROVAL,
        SUPPLY,
        SUPPLY_COLLATERAL,
        BORROW,
        REPAY,
        WITHDRAW,
        WITHDRAW_COLLATERAL,
        SKIM
    }

    /* FUNCTIONS */

    function execute(ActionType[] calldata actions, bytes[] calldata data) external payable;
}
