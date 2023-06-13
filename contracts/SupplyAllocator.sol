// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPool} from "contracts/interfaces/IPool.sol";
import {ISupplyAllocator} from "contracts/interfaces/ISupplyAllocator.sol";

import {Math} from "@morpho-utils/math/Math.sol";
import {PoolLib} from "contracts/libraries/PoolLib.sol";
import {PoolAddress} from "contracts/libraries/PoolAddress.sol";
import {BytesLib, POOL_OFFSET} from "contracts/libraries/BytesLib.sol";

contract SupplyAllocator is ISupplyAllocator {
    using PoolLib for IPool;
    using BytesLib for bytes;

    address internal immutable FACTORY;

    constructor(address factory) {
        FACTORY = factory;
    }

    function getPool(address collateral, address asset) internal view returns (IPool) {
        return IPool(PoolAddress.computeAddress(FACTORY, collateral, asset));
    }

    function allocateSupply(address asset, uint256 amount, bytes memory collateralization)
        external
        view
        returns (bytes memory allocation)
    {
        uint256 highestApr;
        address highestCollateral;
        uint16 highestMaxLtv;

        uint256 length = collateralization.length;
        for (uint256 start; start < length; start += POOL_OFFSET) {
            (address collateral, uint16 maxLtv) = collateralization.decodeCollateralLtv(start);

            uint256 hypotheticalApr = getPool(collateral, asset).apr(maxLtv, amount);

            if (highestApr < hypotheticalApr) {
                highestApr = hypotheticalApr;
                highestCollateral = asset;
                highestMaxLtv = maxLtv;
            }
        }

        allocation = abi.encodePacked(highestCollateral, highestMaxLtv, amount);
    }

    function allocateWithdraw(address asset, uint256 amount, bytes memory collateralization)
        external
        view
        returns (bytes memory allocation)
    {
        uint256 lowestApr;
        address lowestCollateral;
        uint16 lowestMaxLtv;

        uint256 length = collateralization.length;
        for (uint256 start; start < length; start += POOL_OFFSET) {
            (address collateral, uint16 maxLtv) = collateralization.decodeCollateralLtv(start);

            uint256 hypotheticalApr = getPool(collateral, asset).apr(maxLtv, 0);

            if (lowestApr > hypotheticalApr) {
                lowestApr = hypotheticalApr;
                lowestCollateral = asset;
                lowestMaxLtv = maxLtv;
            }
        }

        // Also check for available liquidity to guarantee optimal liquidity (at the cost of sub-optimal APR):

        (amount, allocation) = _maxWithdraw(asset, lowestCollateral, lowestMaxLtv, amount, allocation);

        for (uint256 start; start < length; start += POOL_OFFSET) {
            if (amount == 0) break;

            (address collateral, uint16 maxLtv) = collateralization.decodeCollateralLtv(start);

            if (collateral == lowestCollateral) continue;

            (amount, allocation) = _maxWithdraw(asset, collateral, maxLtv, amount, allocation);
        }
    }

    function _maxWithdraw(address asset, address collateral, uint16 maxLtv, uint256 amount, bytes memory allocation)
        internal
        view
        returns (uint256, bytes memory)
    {
        uint256 withdrawn = Math.min(amount, getPool(collateral, asset).liquidity(maxLtv));

        return (amount - withdrawn, abi.encodePacked(allocation, collateral, maxLtv, withdrawn));
    }
}
