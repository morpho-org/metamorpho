// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import "./helpers/BaseTest.sol";

contract MetaMorphoFactoryTest is BaseTest {
    function testMetaMorphoFactoryAddressZero() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new MetaMorphoFactory(address(0));
    }

    function testCreateMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) public {
        initialOwner = _boundAddressNotZero(initialOwner);
        initialTimelock = bound(initialTimelock, 0, MAX_TIMELOCK);

        address expectedAddress = Clones.predictDeterministicAddress(vaultImpl, salt, address(factory));

        vm.assume(expectedAddress != address(vault));

        vm.expectEmit(address(factory));
        emit EventsLib.CreateMetaMorpho(
            expectedAddress, address(this), initialOwner, initialTimelock, address(loanToken), name, symbol, salt
        );

        MetaMorpho metaMorpho =
            factory.createMetaMorpho(initialOwner, initialTimelock, address(loanToken), name, symbol, salt);

        assertEq(expectedAddress, address(metaMorpho), "computeCreate2Address");

        assertTrue(factory.isMetaMorpho(address(metaMorpho)), "isMetaMorpho");

        assertEq(metaMorpho.owner(), initialOwner, "owner");
        assertEq(address(metaMorpho.MORPHO()), address(morpho), "morpho");
        assertEq(metaMorpho.timelock(), initialTimelock, "timelock");
        assertEq(metaMorpho.asset(), address(loanToken), "asset");
        assertEq(metaMorpho.name(), name, "name");
        assertEq(metaMorpho.symbol(), symbol, "symbol");
    }

    function testCreateMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        string memory name,
        string memory symbol
    ) public {
        initialOwner = _boundAddressNotZero(initialOwner);
        initialTimelock = bound(initialTimelock, 0, MAX_TIMELOCK);

        vm.expectRevert(Clones.ERC1167FailedCreateClone.selector);
        factory.createMetaMorpho(initialOwner, initialTimelock, address(loanToken), name, symbol, bytes32(0));
    }
}
