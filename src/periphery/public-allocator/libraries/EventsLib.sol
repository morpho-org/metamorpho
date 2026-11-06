// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {FlowCapsConfig, Id} from "../interfaces/IPublicAllocator.sol";

/// @title EventsLib
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Library exposing events.
library EventsLib {
    /// @notice Emitted during a public reallocation for each withdrawn-from market.
    event PublicWithdrawal(address indexed sender, address indexed vault, Id indexed id, uint256 withdrawnAssets);

    /// @notice Emitted at the end of a public reallocation.
    event PublicReallocateTo(
        address indexed sender, address indexed vault, Id indexed supplyMarketId, uint256 suppliedAssets
    );

    /// @notice Emitted when the admin is set for a vault.
    event SetAdmin(address indexed sender, address indexed vault, address admin);

    /// @notice Emitted when the fee is set for a vault.
    event SetFee(address indexed sender, address indexed vault, uint256 fee);

    /// @notice Emitted when the fee is transfered for a vault.
    event TransferFee(address indexed sender, address indexed vault, uint256 amount, address indexed feeRecipient);

    /// @notice Emitted when the flow caps are set for a vault.
    event SetFlowCaps(address indexed sender, address indexed vault, FlowCapsConfig[] config);
}
