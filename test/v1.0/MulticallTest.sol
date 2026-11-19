// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/IntegrationTest.sol";

contract MulticallTest is IntegrationTest {
    bytes[] internal data;

    function testMulticall() public {
        data.push(abi.encodeCall(IMetaMorphoBase.setCurator, (address(1))));
        data.push(abi.encodeCall(IMetaMorphoBase.setIsAllocator, (address(1), true)));
        data.push(abi.encodeCall(IMetaMorphoBase.submitTimelock, (ConstantsLib.MAX_TIMELOCK)));

        vm.prank(OWNER);
        vault.multicall(data);

        assertEq(vault.curator(), address(1));
        assertTrue(vault.isAllocator(address(1)));
        assertEq(vault.timelock(), ConstantsLib.MAX_TIMELOCK);
    }
}
