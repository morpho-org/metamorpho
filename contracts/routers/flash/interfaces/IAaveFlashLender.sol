// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface IAaveFlashLender {
    function flashLoan(
        address receiver,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata data,
        uint16 referralCode
    ) external;
}
