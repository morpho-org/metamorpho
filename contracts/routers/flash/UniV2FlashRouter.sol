// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IUniV2Factory} from "./interfaces/IUniV2Factory.sol";
import {IUniV2FlashLender} from "./interfaces/IUniV2FlashLender.sol";
import {IUniV2FlashBorrower} from "./interfaces/IUniV2FlashBorrower.sol";

import {Errors} from "./libraries/Errors.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseFlashRouter} from "./BaseFlashRouter.sol";

uint256 constant FEE_BPS = 30;

abstract contract UniV2FlashRouter is BaseFlashRouter, IUniV2FlashBorrower {
    using SafeTransferLib for ERC20;

    /* TYPES */

    struct UniV2FlashCallbackData {
        address token0;
        address token1;
        bytes data;
    }

    /* IMMUTABLES */

    IUniV2Factory public immutable UNI_V2_FACTORY;

    /* CONSTRUCTOR */

    constructor(address factory) {
        require(factory != address(0), Errors.ZERO_ADDRESS);

        UNI_V2_FACTORY = IUniV2Factory(factory);
    }

    /* CALLBACKS */

    function uniswapV2Call(address, uint256 amount0, uint256 amount1, bytes calldata data) external {
        UniV2FlashCallbackData memory flashData = abi.decode(data, (UniV2FlashCallbackData));

        _onCallback(data);

        uint256 repaid0 = amount0 * 100_00 / FEE_BPS;
        uint256 repaid1 = amount1 * 100_00 / FEE_BPS;

        ERC20(flashData.token0).safeTransferFrom(_initiator, msg.sender, repaid0);
        ERC20(flashData.token1).safeTransferFrom(_initiator, msg.sender, repaid1);
    }

    /* EXTERNAL */

    /// @dev Triggers a flash swap on Uniswap V2.
    function uniV2FlashSwap(address token0, address token1, uint256 amount0, uint256 amount1, bytes calldata data)
        external
    {
        IUniV2FlashLender(UNI_V2_FACTORY.getPair(token0, token1)).swap(
            amount0,
            amount1,
            address(this),
            abi.encode(UniV2FlashCallbackData({token0: token0, token1: token1, data: data}))
        );
    }
}
