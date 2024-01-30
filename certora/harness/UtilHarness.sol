// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IERC20} from "../munged/MetaMorpho.sol";

contract MetaMorphoHarness {
    function balanceOf(address token, address user) external view returns (uint256) {
        return IERC20(token).balanceOf(user);
    }

    function totalSupply(address token) external view returns (uint256) {
        return IERC20(token).totalSupply();
    }

    function transferFrom(address token, address from, address to, uint256 amount) external {
        IERC20(token).transferFrom(from, to, amount);
    }
}
