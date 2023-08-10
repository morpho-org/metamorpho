// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IUniV3FlashLender} from "./interfaces/IUniV3FlashLender.sol";
import {IUniV3FlashBorrower} from "./interfaces/IUniV3FlashBorrower.sol";

import {Errors} from "./libraries/Errors.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {PoolAddress} from "@uniswap/v3-periphery/libraries/PoolAddress.sol";

import {BaseFlashRouter} from "./BaseFlashRouter.sol";

abstract contract UniV3FlashRouter is BaseFlashRouter, IUniV3FlashBorrower {
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

    address public immutable UNI_V3_FACTORY;

    /* CONSTRUCTOR */

    constructor(address factory) {
        require(factory != address(0), Errors.ZERO_ADDRESS);

        UNI_V3_FACTORY = factory;
    }

    /* CALLBACKS */

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        UniV3FlashCallbackData memory flashData = abi.decode(data, (UniV3FlashCallbackData));

        _onCallback(data);

        uint256 repaid0 = flashData.amount0 + fee0;
        uint256 repaid1 = flashData.amount1 + fee1;

        ERC20(flashData.token0).safeTransferFrom(_initiator, msg.sender, repaid0);
        ERC20(flashData.token1).safeTransferFrom(_initiator, msg.sender, repaid1);
    }

    /* EXTERNAL */

    /// @dev Triggers a flash swap on Uniswap V3.
    function uniV3FlashSwap(PoolAddress.PoolKey calldata poolKey, uint256 amount0, uint256 amount1, bytes calldata data)
        external
    {
        IUniV3FlashLender(UNI_V3_FACTORY.computeAddress(poolKey)).flash(
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
