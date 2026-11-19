// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {IMetaMorphoV1_1} from "./interfaces/IMetaMorphoV1_1.sol";
import {IMetaMorphoV1_1Factory} from "./interfaces/IMetaMorphoV1_1Factory.sol";

import {EventsLib} from "./libraries/EventsLib.sol";
import {ErrorsLib} from "./libraries/ErrorsLib.sol";

import {MetaMorphoV1_1} from "./MetaMorphoV1_1.sol";

/// @title MetaMorphoV1_1Factory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice This contract allows to create MetaMorphoV1_1 vaults, and to index them easily.
contract MetaMorphoV1_1Factory is IMetaMorphoV1_1Factory {
    /* IMMUTABLES */

    /// @inheritdoc IMetaMorphoV1_1Factory
    address public immutable MORPHO;

    /* STORAGE */

    /// @inheritdoc IMetaMorphoV1_1Factory
    mapping(address => bool) public isMetaMorpho;

    /* CONSTRUCTOR */

    /// @dev Initializes the contract.
    /// @param morpho The address of the Morpho contract.
    constructor(address morpho) {
        if (morpho == address(0)) revert ErrorsLib.ZeroAddress();

        MORPHO = morpho;
    }

    /* EXTERNAL */

    /// @inheritdoc IMetaMorphoV1_1Factory
    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IMetaMorphoV1_1 metaMorpho) {
        metaMorpho = IMetaMorphoV1_1(
            address(new MetaMorphoV1_1{salt: salt}(initialOwner, MORPHO, initialTimelock, asset, name, symbol))
        );

        isMetaMorpho[address(metaMorpho)] = true;

        emit EventsLib.CreateMetaMorpho(
            address(metaMorpho), msg.sender, initialOwner, initialTimelock, asset, name, symbol, salt
        );
    }
}
