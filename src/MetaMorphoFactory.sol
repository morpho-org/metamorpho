// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IMetaMorpho} from "./interfaces/IMetaMorpho.sol";

import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {MetaMorpho} from "./MetaMorpho.sol";

/// @title MetaMorphoFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice This contract allows to create MetaMorpho vaults, and to index them easily.
contract MetaMorphoFactory {
    /* IMMUTABLES */

    /// @notice The address of the MetaMorpho implementation contract.
    address public immutable METAMORPHO_IMPL;

    /* STORAGE */

    /// @notice Whether a MetaMorpho vault was created with the factory.
    mapping(address => bool) public isMetaMorpho;

    /* CONSTRCUTOR */

    /// @dev Initializes the contract.
    /// @param implementation The address of the MetaMorpho implementation contract.
    constructor(address implementation) {
        if (implementation == address(0)) revert ErrorsLib.ZeroAddress();

        METAMORPHO_IMPL = implementation;
    }

    /* EXTERNAL */

    /// @notice Creates a new MetaMorpho vault.
    /// @param initialOwner The owner of the vault.
    /// @param initialTimelock The initial timelock of the vault.
    /// @param asset The address of the underlying asset.
    /// @param name The name of the vault.
    /// @param symbol The symbol of the vault.
    /// @param salt The salt to use for the MetaMorpho vault's CREATE2 address.
    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (MetaMorpho metaMorpho) {
        metaMorpho = MetaMorpho(Clones.cloneDeterministic(METAMORPHO_IMPL, salt));

        metaMorpho.initialize(initialOwner, initialTimelock, asset, name, symbol);

        isMetaMorpho[address(metaMorpho)] = true;

        emit EventsLib.CreateMetaMorpho(
            address(metaMorpho), msg.sender, initialOwner, initialTimelock, asset, name, symbol, salt
        );
    }
}
