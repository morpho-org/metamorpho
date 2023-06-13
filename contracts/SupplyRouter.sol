// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPool} from "contracts/interfaces/IPool.sol";
import {ISupplyRouter} from "contracts/interfaces/ISupplyRouter.sol";

import {PoolAddress} from "contracts/libraries/PoolAddress.sol";
import {BytesLib, POOL_OFFSET} from "contracts/libraries/BytesLib.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

contract SupplyRouter is ISupplyRouter {
    using BytesLib for bytes;
    using SafeTransferLib for ERC20;

    address internal immutable _FACTORY;

    constructor(address factory) {
        _FACTORY = factory;
    }

    /* EXTERNAL */

    function supply(address asset, bytes calldata allocation, address onBehalf) external {
        uint256 length = allocation.length;

        for (uint256 start; start < length; start += POOL_OFFSET) {
            (address collateral, uint256 amount, uint16 maxLtv) = allocation.decodePoolAllocation(start);

            ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

            IPool pool = _pool(collateral, asset);
            pool.supply(amount, maxLtv, onBehalf);
        }
    }

    function withdraw(address asset, bytes calldata allocation, address receiver) external {
        uint256 length = allocation.length;

        for (uint256 start; start < length; start += POOL_OFFSET) {
            (address collateral, uint256 amount, uint16 maxLtv) = allocation.decodePoolAllocation(start);

            IPool pool = _pool(collateral, asset);
            pool.withdraw(
                amount,
                maxLtv,
                msg.sender, // TODO: could be _msgSender() to be meta-tx compliant or could use a built-in authorization layer to withdraw on behalf of another address
                receiver
            );
        }
    }

    /* INTERNAL */

    function _pool(address collateral, address asset) internal view returns (IPool) {
        return IPool(PoolAddress.computeAddress(_FACTORY, collateral, asset));
    }
}
