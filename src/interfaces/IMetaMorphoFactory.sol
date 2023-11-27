// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IMetaMorpho} from "./IMetaMorpho.sol";

/// @title IMetaMorphoFactory
/// @author Morpho Labs
/// @custom:contact security@morpho.org
/// @notice Interface of MetaMorpho's factory.
interface IMetaMorphoFactory {
    function MORPHO() external returns (address);

    function isMetaMorpho(address target) external returns (bool);

    function createMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (IMetaMorpho metaMorpho);
}
