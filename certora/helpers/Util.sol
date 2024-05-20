// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {
    MarketParams,
    MarketParamsLib,
    IERC20,
    SafeERC20,
    IMorphoHarness,
    SharesMathLib,
    Id,
    Market
} from "../munged/MetaMorpho.sol";

import {MorphoBalancesLib} from "../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";
import {IMorpho} from "../../lib/morpho-blue/src/interfaces/IMorpho.sol";

contract Util {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;
    using MorphoBalancesLib for IMorpho;

    function balanceOf(address token, address user) external view returns (uint256) {
        return IERC20(token).balanceOf(user);
    }

    function totalSupply(address token) external view returns (uint256) {
        return IERC20(token).totalSupply();
    }

    function safeTransferFrom(address token, address from, address to, uint256 amount) external {
        IERC20(token).safeTransferFrom(from, to, amount);
    }

    function withdrawnAssets(IMorphoHarness morpho, Id id, uint256 assets, uint256 shares)
        external
        view
        returns (uint256)
    {
        if (shares == 0) {
            return assets;
        } else {
            Market memory market = morpho.market(id);
            return shares.toAssetsDown(market.totalSupplyAssets, market.totalSupplyShares);
        }
    }

    function expectedSupplyAssets(address morpho, MarketParams memory marketParams, address user)
        external
        view
        returns (uint256)
    {
        return IMorpho(morpho).expectedSupplyAssets(marketParams, user);
    }

    function libId(MarketParams memory marketParams) external pure returns (Id) {
        return marketParams.id();
    }
}
