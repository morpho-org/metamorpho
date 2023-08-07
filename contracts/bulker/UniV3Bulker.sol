// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IUniV3FlashLender} from "./interfaces/IUniV3FlashLender.sol";
import {IUniV3FlashBorrower} from "./interfaces/IUniV3FlashBorrower.sol";

import {Errors} from "./libraries/Errors.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {PoolAddress} from "@uniswap/v3-periphery/libraries/PoolAddress.sol";

import {BaseBulker} from "./BaseBulker.sol";

abstract contract UniV3Bulker is BaseBulker, IUniV3FlashBorrower {
    using SafeTransferLib for ERC20;
    using PoolAddress for address;

    /* TYPES */

    struct UniV3FlashCallbackData {
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        bytes data;
    }

    /* IMMUTABLES */

    address internal immutable _UNI_V3_FACTORY;

    /* CONSTRUCTOR */

    constructor(address factory) {
        require(factory != address(0), Errors.ZERO_ADDRESS);

        _UNI_V3_FACTORY = factory;
    }

    /* CALLBACKS */

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external callback(data) {
        _checkInitiated();

        UniV3FlashCallbackData memory flashData = abi.decode(data, (UniV3FlashCallbackData));

        _multicall(abi.decode(flashData.data, (bytes[])));

        ERC20(flashData.token0).safeApprove(msg.sender, flashData.amount0 + fee0);
        ERC20(flashData.token1).safeApprove(msg.sender, flashData.amount1 + fee1);
    }

    /* INTERNAL */

    /// @dev Triggers a flash swap on Uniswap V3.
    function uniV3FlashSwap(PoolAddress.PoolKey memory poolKey, uint256 amount0, uint256 amount1, bytes calldata data)
        external
    {
        IUniV3FlashLender(_UNI_V3_FACTORY.computeAddress(poolKey)).flash(
            address(this),
            amount0,
            amount1,
            abi.encode(
                UniV3FlashCallbackData({
                    token0: poolKey.token0,
                    token1: poolKey.token1,
                    amount0: amount0,
                    amount1: amount1,
                    data: data
                })
            )
        );
    }
}
