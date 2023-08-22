// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {BaseFlashRouter} from "../BaseFlashRouter.sol";
import {AaveV2FlashRouter} from "../AaveV2FlashRouter.sol";
import {AaveV3FlashRouter} from "../AaveV3FlashRouter.sol";
import {BalancerFlashRouter} from "../BalancerFlashRouter.sol";
import {MorphoFlashRouter} from "../MorphoFlashRouter.sol";
import {UniV2FlashRouter} from "../UniV2FlashRouter.sol";
import {UniV3FlashRouter} from "../UniV3FlashRouter.sol";
import {MakerFlashRouter} from "./MakerFlashRouter.sol";

contract EthereumFlashRouter is
    BaseFlashRouter,
    AaveV2FlashRouter,
    AaveV3FlashRouter,
    BalancerFlashRouter,
    MakerFlashRouter,
    UniV2FlashRouter,
    UniV3FlashRouter,
    MorphoFlashRouter
{
    constructor(address morpho)
        AaveV2FlashRouter(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9)
        AaveV3FlashRouter(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2)
        BalancerFlashRouter(0xBA12222222228d8Ba445958a75a0704d566BF2C8)
        MakerFlashRouter(0x60744434d6339a6B27d73d9Eda62b6F66a0a04FA)
        UniV2FlashRouter(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f)
        UniV3FlashRouter(0x1F98431c8aD98523631AE4a59f267346ea31F984)
        MorphoFlashRouter(morpho)
    {}
}
