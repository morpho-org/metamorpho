// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

contract TimelockTest is BaseTest {
    function testSubmitPendingTimelock(uint192 timelock) public {
        timelock = uint192(bound(timelock, 0, MAX_TIMELOCK));
        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        (uint192 value, uint64 timestamp) = vault.pendingTimelock();
        assertEq(value, timelock);
        assertEq(timestamp, block.timestamp);
    }

    function testSubmitPendingTimelockRevertNotOwner(uint192 timelock) public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.submitTimelock(timelock);
    }

    function testSubmitPendingTimelockRevertMaxTimelockExceeded(uint192 timelock) public {
        timelock = uint192(bound(timelock, MAX_TIMELOCK + 1, type(uint192).max));

        vm.prank(OWNER);
        vm.expectRevert(bytes(ErrorsLib.MAX_TIMELOCK_EXCEEDED));
        vault.submitTimelock(timelock);
    }

    function testSetTimelock(uint192 timelock) public {
        timelock = uint192(bound(timelock, 0, MAX_TIMELOCK));

        vm.startPrank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + vault.timelock());

        vault.acceptTimelock();
        vm.stopPrank();

        assertEq(vault.timelock(), timelock);
    }

    function testSetTimelockRevertNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.acceptTimelock();
    }
}
