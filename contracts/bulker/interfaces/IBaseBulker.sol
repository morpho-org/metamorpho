// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IBaseBulker {
    /* TYPES */

    enum ActionType {
        APPROVE2,
        TRANSFER_FROM2,
        SET_AUTHORIZATION,
        SUPPLY,
        SUPPLY_COLLATERAL,
        BORROW,
        REPAY,
        WITHDRAW,
        WITHDRAW_COLLATERAL,
        WRAP_ETH,
        UNWRAP_ETH,
        WRAP_ST_ETH,
        UNWRAP_ST_ETH,
        SKIM,
        UNI_SWAP,
        CRV_V1_SWAP,
        CRV_V2_SWAP,
        BALANCER_V2_SWAP,
        BLUE_FLASH_LOAN,
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
