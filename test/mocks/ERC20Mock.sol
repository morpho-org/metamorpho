// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    /// @dev Required for ERC4626-compliance tests.
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    /// @dev Required for ERC4626-compliance tests.
    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function setBalance(address account, uint256 amount) external {
        _burn(account, balanceOf(account));
        _mint(account, amount);
    }
}
