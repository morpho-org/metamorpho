// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/IntegrationTest.sol";

import "../../src/v1.1/MetaMorphoV1_1Factory.sol";

contract MetaMorphoFactoryTest is IntegrationTest {
    MetaMorphoV1_1Factory factory;

    function setUp() public override {
        super.setUp();

        factory = new MetaMorphoV1_1Factory(address(morpho));
    }

    function testFactoryAddressZero() public {
        vm.expectRevert(ErrorsLib.ZeroAddress.selector);
        new MetaMorphoV1_1Factory(address(0));
    }

    function testCreateMetaMorpho(
        address initialOwner,
        uint256 initialTimelock,
        string memory name,
        string memory symbol,
        bytes32 salt
    ) public {
        vm.assume(address(initialOwner) != address(0));
        initialTimelock = _boundInitialTimelock(initialTimelock);

        bytes32 initCodeHash = hashInitCode(
            type(MetaMorphoV1_1).creationCode,
            abi.encode(initialOwner, address(morpho), initialTimelock, address(loanToken), name, symbol)
        );
        address expectedAddress = computeCreate2Address(salt, initCodeHash, address(factory));

        vm.expectEmit(address(factory));
        emit EventsLib.CreateMetaMorpho(
            expectedAddress, address(this), initialOwner, initialTimelock, address(loanToken), name, symbol, salt
        );

        IMetaMorphoV1_1 metaMorpho =
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
}
