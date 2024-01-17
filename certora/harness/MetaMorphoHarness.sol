// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import "../munged/MetaMorpho.sol";

contract MetaMorphoHarness is MetaMorpho {
    constructor(
        address owner,
        address morpho,
        uint256 initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) MetaMorpho(owner, morpho, initialTimelock, _asset, _name, _symbol) {}

    function balanceOf(address token, address user) external view returns (uint256) {
        return IERC20(token).balanceOf(user);
    }

    function totalSupply(address token) external view returns (uint256) {
        return IERC20(token).totalSupply();
    }

    function transferFrom(address token, address from, address to, uint256 amount) external {
        IERC20(token).transferFrom(from, to, amount);
    }

    function minTimelock() external pure returns (uint256) {
        return ConstantsLib.MIN_TIMELOCK;
    }

    function maxTimelock() external pure returns (uint256) {
        return ConstantsLib.MAX_TIMELOCK;
    }

    function maxQueueLength() external pure returns (uint256) {
        return ConstantsLib.MAX_QUEUE_LENGTH;
    }

    function maxFee() external pure returns (uint256) {
        return ConstantsLib.MAX_FEE;
    }
}
