// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPool} from "contracts/interfaces/IPool.sol";
import {IFactory} from "contracts/interfaces/IFactory.sol";

import {FactoryLib} from "contracts/libraries/FactoryLib.sol";
import {BytesLib, POOL_OFFSET} from "contracts/libraries/BytesLib.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

contract InternalSupplyRouter is Context {
    using BytesLib for bytes;
    using FactoryLib for IFactory;
    using SafeTransferLib for ERC20;

    IFactory internal immutable _FACTORY;

    constructor(address factory) {
        _FACTORY = IFactory(factory);
    }

    /* INTERNAL */

    function _decodePoolAllocation(address asset, bytes calldata allocation, uint256 start)
        internal
        view
        returns (IPool pool, uint256 amount, uint16 bucket)
    {
        address collateral;
        (collateral, amount, bucket) = allocation.decodePoolAllocation(start);

        pool = _FACTORY.getPool(asset, collateral);
    }

    function _supply(address asset, bytes calldata allocation, address onBehalf) internal {
        uint256 length = allocation.length;

        for (uint256 start; start < length; start += POOL_OFFSET) {
            (IPool pool, uint256 amount, uint16 maxLtv) = _decodePoolAllocation(asset, allocation, start);

            ERC20(asset).safeTransferFrom(_msgSender(), address(this), amount);

            pool.supply(amount, maxLtv, onBehalf);
        }
    }

    function _withdraw(address asset, bytes calldata allocation, address receiver) internal {
        uint256 length = allocation.length;

        for (uint256 start; start < length; start += POOL_OFFSET) {
            (IPool pool, uint256 amount, uint16 maxLtv) = _decodePoolAllocation(asset, allocation, start);

            pool.withdraw(amount, maxLtv, _msgSender(), receiver);
        }
    }
}
