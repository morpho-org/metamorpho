// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

contract MulticallTest is BaseTest {
    bytes[] internal data;

    function testMulticall() public {
        data.push(abi.encodeCall(MetaMorpho.setRiskManager, (address(1))));
        data.push(abi.encodeCall(MetaMorpho.setIsAllocator, (address(1), true)));
        data.push(abi.encodeCall(MetaMorpho.submitTimelock, (1)));

        vm.prank(OWNER);
        vault.multicall(data);

        assertEq(vault.riskManager(), address(1));
        assertTrue(vault.isAllocator(address(1)));
        assertEq(vault.timelock(), 1);
    }
}
