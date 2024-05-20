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

contract Util {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;

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

    function supplyAssets(IMorphoHarness morpho, Id id, address user) external view returns (uint256) {
        uint256 shares = morpho.supplyShares(id, user);
        Market memory market = morpho.market(id);
        return shares.toAssetsDown(market.totalSupplyAssets, market.totalSupplyShares);
    }

    function libId(MarketParams memory marketParams) external pure returns (Id) {
        return marketParams.id();
    }
}
