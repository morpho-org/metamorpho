// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

contract TimelockTest is BaseTest {
    function testSubmitTimelock(uint256 timelock) public {
        timelock = bound(timelock, 0, MAX_TIMELOCK);

        vm.assume(timelock != TIMELOCK);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        (uint256 value, uint64 timestamp) = vault.pendingTimelock();

        assertEq(value, timelock);
        assertEq(timestamp, block.timestamp);
    }

    function testSubmitTimelockNotOwner(uint256 timelock) public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.submitTimelock(timelock);
    }

    function testSubmitTimelockMaxTimelockExceeded(uint256 timelock) public {
        timelock = bound(timelock, MAX_TIMELOCK + 1, type(uint256).max);

        vm.prank(OWNER);
        vm.expectRevert(bytes(ErrorsLib.MAX_TIMELOCK_EXCEEDED));
        vault.submitTimelock(timelock);
    }

    function testAcceptTimelock(uint256 timelock) public {
        timelock = bound(timelock, 0, MAX_TIMELOCK);

        vm.assume(timelock != TIMELOCK);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + TIMELOCK);

        vm.prank(OWNER);
        vault.acceptTimelock();

        assertEq(vault.timelock(), timelock);
    }

    function testAcceptTimelockNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.acceptTimelock();
    }

    function testAcceptTimelockNotElapsed(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, 0, MAX_TIMELOCK);
        elapsed = bound(elapsed, 1, TIMELOCK - 1);

        vm.assume(timelock != TIMELOCK);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.prank(OWNER);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_ELAPSED));
        vault.acceptTimelock();
    }

    function testAcceptTimelockExpirationExceeded(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, 0, MAX_TIMELOCK);
        elapsed = bound(elapsed, TIMELOCK + TIMELOCK_EXPIRATION + 1, type(uint64).max);

        vm.assume(timelock != TIMELOCK);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.prank(OWNER);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED));
        vault.acceptTimelock();
    }
}
