// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

import {MetaMorpho} from "./MetaMorpho.sol";

contract MetaMorphoFactory {
    /* IMMUTABLES */

    address public immutable MORPHO;

    /* STORAGE */

    mapping(address => address) public metaMorphoDeployer;

    /* CONSTRCUTOR */

    constructor(address morpho) {
        require(morpho != address(0), ErrorsLib.ZERO_ADDRESS);

        MORPHO = morpho;
    }

    /* EXTERNAL */

    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (MetaMorpho metaMorpho) {
        metaMorpho = new MetaMorpho{salt: salt}(initialOwner, MORPHO, initialTimelock, asset, name, symbol);

        metaMorphoDeployer[address(metaMorpho)] = msg.sender;

        emit EventsLib.CreateMetaMorpho(
            address(metaMorpho), msg.sender, initialOwner, initialTimelock, asset, name, symbol, salt
        );
    }

    function isMetaMorpho(address metaMorpho) public view returns (bool) {
        return metaMorphoDeployer[metaMorpho] != address(0);
    }
}
