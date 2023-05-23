// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPool} from "src/interfaces/IPool.sol";
import {ISupplyAllocator} from "src/interfaces/ISupplyAllocator.sol";

import {PoolLib} from "src/libraries/PoolLib.sol";
import {PoolAddress} from "src/libraries/PoolAddress.sol";
import {BytesLib, POOL_OFFSET} from "src/libraries/BytesLib.sol";

contract SupplyAllocator is ISupplyAllocator {
    using PoolLib for IPool;
    using BytesLib for bytes;

    address internal immutable FACTORY;

    constructor(address factory) {
        FACTORY = factory;
    }

    function getPool(
        address collateral,
        address asset
    ) internal view returns (IPool) {
        return IPool(PoolAddress.computeAddress(FACTORY, collateral, asset));
    }

    function allocateSupply(
        address asset,
        uint256 amount,
        bytes memory collateralization
    ) external returns (bytes memory allocation) {
        uint256 highestApr;
        bytes memory highestCollateralLtv;

        uint256 length = collateralization.length;
        for (uint256 start; start < length; start += POOL_OFFSET) {
            (address collateral, uint16 maxLtv) = collateralization
                .decodeCollateralLtv(start);

            IPool pool = getPool(collateral, asset);
            uint256 hypotheticalApr = pool.apr(maxLtv, amount, 0);

            if (highestApr < hypotheticalApr) {
                highestApr = hypotheticalApr;
                highestCollateralLtv = abi.encodePacked(asset, maxLtv);
            }
        }

        allocation = abi.encodePacked(highestCollateralLtv, amount);
    }

    function allocateWithdraw(
        address asset,
        uint256 amount,
        bytes memory collateralization
    ) external returns (bytes memory allocation) {
        uint256 lowestApr;
        bytes memory lowestCollateralLtv;

        uint256 length = collateralization.length;
        for (uint256 start; start < length; start += POOL_OFFSET) {
            (address collateral, uint16 maxLtv) = collateralization
                .decodeCollateralLtv(start);

            IPool pool = getPool(collateral, asset);
            uint256 hypotheticalApr = pool.apr(maxLtv, 0, amount);

            if (lowestApr > hypotheticalApr) {
                lowestApr = hypotheticalApr;
                lowestCollateralLtv = abi.encodePacked(asset, maxLtv);
            }
        }

        allocation = abi.encodePacked(lowestCollateralLtv, amount);
    }
}
