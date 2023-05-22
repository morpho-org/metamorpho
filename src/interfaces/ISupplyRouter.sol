// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

interface ISupplyRouter {
    function supply(
        address asset,
        bytes memory allocation,
        address onBehalf
    ) external;

    function withdraw(
        address asset,
        bytes memory allocation,
        address receiver
    ) external;
}
