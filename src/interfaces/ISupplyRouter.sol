// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.5.0;

import {LiquidityAllocation} from "src/libraries/Types.sol";

interface ISupplyRouter {
    function supply(
        LiquidityAllocation[] calldata allocation,
        address onBehalf
    ) external;

    function withdraw(
        LiquidityAllocation[] calldata allocation,
        address receiver
    ) external;
}
