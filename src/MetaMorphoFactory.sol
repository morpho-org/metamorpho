// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IMetaMorpho} from "./interfaces/IMetaMorpho.sol";
import {IMetaMorphoFactory} from "./interfaces/IMetaMorphoFactory.sol";

import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

import {MetaMorpho} from "./MetaMorpho.sol";

/// @title MetaMorphoFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice This contract allows to create MetaMorpho vaults, and to index them easily.
contract MetaMorphoFactory is IMetaMorphoFactory {
    /* IMMUTABLES */

    /// @inheritdoc IMetaMorphoFactory
    address public immutable MORPHO;

    /* STORAGE */

    /// @inheritdoc IMetaMorphoFactory
    mapping(address => bool) public isMetaMorpho;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param morpho The address of the Morpho contract.
    constructor(address morpho) {
        if (morpho == address(0)) revert ErrorsLib.ZeroAddress();

        MORPHO = morpho;
    }

    /* EXTERNAL */

    /// @inheritdoc IMetaMorphoFactory
    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IMetaMorpho metaMorpho) {
        metaMorpho =
            IMetaMorpho(address(new MetaMorpho{salt: salt}(initialOwner, MORPHO, initialTimelock, asset, name, symbol)));

        isMetaMorpho[address(metaMorpho)] = true;

        emit EventsLib.CreateMetaMorpho(
            address(metaMorpho), msg.sender, initialOwner, initialTimelock, asset, name, symbol, salt
        );
    }
}
