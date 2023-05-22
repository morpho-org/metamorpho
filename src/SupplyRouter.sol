// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPool} from "src/interfaces/IPool.sol";
import {ISupplyRouter} from "src/interfaces/ISupplyRouter.sol";

import {LiquidityAllocation, PoolLiquidityAllocation} from "src/libraries/Types.sol";
import {AllocationLib} from "src/libraries/AllocationLib.sol";

contract SupplyRouter is ISupplyRouter {
    using AllocationLib for bytes;
    using SafeTransferLib for ERC20;

    function supply(
        address asset,
        bytes memory allocation,
        address onBehalf
    ) external {
        address collateral;
        uint256 amount;
        uint16 maxLtv;

        while (allocation.length > 0) {
            (collateral, amount, maxLtv, allocation) = allocation.decodeFirst();

            ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

            address pool = getPool(collateral, asset);
            IPool(pool).supply(amount, maxLtv, onBehalf);
        }
    }

    function withdraw(bytes memory allocation, address receiver) external {
        address collateral;
        uint256 amount;
        uint16 maxLtv;

        while (allocation.length > 0) {
            (collateral, amount, maxLtv, allocation) = allocation.decodeFirst();

            address pool = getPool(collateral, asset);
            IPool(pool).withdraw(
                amount,
                maxLtv,
                msg.sender, // TODO: could be _msgSender() to be meta-tx compliant or could use a built-in authorization layer to withdraw on behalf of another address
                receiver
            );
        }
    }
}
