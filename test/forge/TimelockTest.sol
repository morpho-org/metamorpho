// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

contract TimelockTest is BaseTest {
    function testSubmitPendingTimelock(uint256 timelock) public {
        timelock = bound(timelock, 0, vault.MAX_TIMELOCK());
        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        (uint128 value, uint128 timestamp) = vault.pendingTimelock();
        assertEq(value, timelock);
        assertEq(timestamp, block.timestamp);
    }

    function testSubmitPendingTimelockShouldRevertWhenNotOwner(uint256 timelock) public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.submitTimelock(timelock);
    }

    function testSubmitPendingTimelockShouldRevertWhenMaxTimelockExceeded(uint256 timelock) public {
        timelock = bound(timelock, vault.MAX_TIMELOCK() + 1, type(uint256).max);

        vm.prank(OWNER);
        vm.expectRevert(bytes(ErrorsLib.MAX_TIMELOCK_EXCEEDED));
        vault.submitTimelock(timelock);
    }

    function testSetTimelock(uint256 timelock) public {
        timelock = bound(timelock, 0, vault.MAX_TIMELOCK());
        vm.startPrank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + vault.timelock());

        vault.setTimelock();
        vm.stopPrank();

        assertEq(vault.timelock(), timelock);
    }

    function testSetTimelockShouldRevertWhenNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setTimelock();
    }
}
