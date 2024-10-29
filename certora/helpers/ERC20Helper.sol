// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IERC20, SafeERC20, IMorphoHarness, SharesMathLib, Id, Market} from "../munged/MetaMorpho.sol";

contract ERC20Helper {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;

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
}
