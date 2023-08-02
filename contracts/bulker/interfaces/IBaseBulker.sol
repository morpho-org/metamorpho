// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IBaseBulker {
    /* TYPES */

    enum ActionType {
        SKIM, // Common
        // ERC20
        ERC20_APPROVE2,
        ERC20_TRANSFER_FROM2,
        // Blue
        BLUE_SET_AUTHORIZATION,
        BLUE_SUPPLY,
        BLUE_SUPPLY_COLLATERAL,
        BLUE_BORROW,
        BLUE_REPAY,
        BLUE_WITHDRAW,
        BLUE_WITHDRAW_COLLATERAL,
        BLUE_FLASH_LOAN,
        // Native token
        WRAP_NATIVE,
        UNWRAP_NATIVE,
        // StEth token
        WRAP_ST_ETH,
        UNWRAP_ST_ETH,
        // Swaps
        UNI_SWAP,
        CRV_V1_SWAP,
        CRV_V2_SWAP,
        BALANCER_V2_SWAP,
        // Flash Loans
        AAVE_V2_FLASH_LOAN,
        AAVE_V3_FLASH_LOAN,
        MAKER_FLASH_LOAN,
        BALANCER_FLASH_LOAN
    }

    struct Action {
        ActionType actionType;
        bytes data;
    }

    /// @notice Contains the `v`, `r` and `s` parameters of an ECDSA signature.
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /* ERRORS */

    /// @notice Thrown when an address parameter is the bulker's address.
    error AddressIsBulker();

    /// @notice Thrown when an address used as parameter is the zero address.
    error AddressIsZero();

    /// @notice Thrown when an amount used as parameter is zero.
    error AmountIsZero();

    /// @notice Thrown when the given action is unsupported.
    error UnsupportedAction(ActionType action);

    /// @notice Thrown when the bulker is not initiated.
    error Uninitiated();

    /* FUNCTIONS */

    function execute(Action[] calldata actions) external payable;
}
