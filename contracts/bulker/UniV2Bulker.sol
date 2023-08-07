// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IUniV2Factory} from "./interfaces/IUniV2Factory.sol";
import {IUniV2FlashLender} from "./interfaces/IUniV2FlashLender.sol";
import {IUniV2FlashBorrower} from "./interfaces/IUniV2FlashBorrower.sol";

import {Errors} from "./libraries/Errors.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {BaseBulker} from "./BaseBulker.sol";

abstract contract UniV2Bulker is BaseBulker, IUniV2FlashBorrower {
    using SafeTransferLib for ERC20;

    /* TYPES */

    struct FlashCallbackData {
        address token0;
        address token1;
        bytes data;
    }

    /* CONSTANTS */

    uint256 private constant FEE_BPS = 30;

    /* IMMUTABLES */

    IUniV2Factory internal immutable _FACTORY;

    /* CONSTRUCTOR */

    constructor(address factory) {
        require(factory != address(0), Errors.ZERO_ADDRESS);

        _FACTORY = IUniV2Factory(factory);
    }

    /* CALLBACKS */

    function uniswapV2Call(address, uint256 amount0, uint256 amount1, bytes calldata data) external {
        _checkInitiated();

        FlashCallbackData memory flashData = abi.decode(data, (FlashCallbackData));

        _multicall(abi.decode(flashData.data, (bytes[])));

        ERC20(flashData.token0).safeApprove(msg.sender, amount0 * 100_00 / FEE_BPS);
        ERC20(flashData.token1).safeApprove(msg.sender, amount1 * 100_00 / FEE_BPS);
    }

    /* INTERNAL */

    /// @dev Triggers a flash swap on Uniswap V2.
    function uniV2FlashSwap(address token0, address token1, uint256 amount0, uint256 amount1, bytes calldata data)
        external
    {
        IUniV2FlashLender(_FACTORY.getPair(token0, token1)).swap(
            amount0, amount1, address(this), abi.encode(FlashCallbackData({token0: token0, token1: token1, data: data}))
        );
    }
}
