// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {EventsLib} from "./libraries/EventsLib.sol";

import {MetaMorpho} from "./MetaMorpho.sol";

contract MetaMorphoFactory {
    /* STORAGE */

    mapping(address => bool) public isMetaMorpho;

    /* EXTERNAL */

    function createMetaMorpho(
        address initialOwner,
        address morpho,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (MetaMorpho metaMorpho) {
        metaMorpho = new MetaMorpho{salt: salt}(initialOwner, morpho, initialTimelock, asset, name, symbol);

        isMetaMorpho[address(metaMorpho)] = true;

        emit EventsLib.CreateMetaMorpho(
            address(metaMorpho), msg.sender, initialOwner, morpho, initialTimelock, asset, name, symbol, salt
        );
    }
}
