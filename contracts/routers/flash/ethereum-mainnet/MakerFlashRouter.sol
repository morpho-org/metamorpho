// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IERC3156FlashLender} from "../interfaces/IERC3156FlashLender.sol";

import {Errors} from "../libraries/Errors.sol";

import {ERC3156FlashRouter} from "../ERC3156FlashRouter.sol";

abstract contract MakerFlashRouter is ERC3156FlashRouter {
    /* IMMUTABLES */

    IERC3156FlashLender public immutable MAKER_VAULT;

    /* CONSTRUCTOR */

    constructor(address makerVault) {
        require(makerVault != address(0), Errors.ZERO_ADDRESS);

        MAKER_VAULT = IERC3156FlashLender(makerVault);
    }

    /* ACTIONS */

    /// @dev Triggers a flash loan on Maker.
    function makerFlashLoan(address asset, uint256 amount, bytes calldata data) external {
        _erc3156FlashLoan(MAKER_VAULT, asset, amount, data);
    }
}
