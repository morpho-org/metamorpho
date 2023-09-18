// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

contract TimelockTest is BaseTest {
    function testSubmitTimelock(uint192 timelock) public {
        timelock = uint192(bound(timelock, 0, MAX_TIMELOCK));

        vm.assume(timelock != vault.timelock());

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        (uint192 value, uint64 timestamp) = vault.pendingTimelock();

        assertEq(value, timelock);
        assertEq(timestamp, block.timestamp);
    }

    function testSubmitTimelockNotOwner(uint192 timelock) public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.submitTimelock(timelock);
    }

    function testSubmitTimelockMaxTimelockExceeded(uint192 timelock) public {
        timelock = uint192(bound(timelock, MAX_TIMELOCK + 1, type(uint192).max));

        vm.prank(OWNER);
        vm.expectRevert(bytes(ErrorsLib.MAX_TIMELOCK_EXCEEDED));
        vault.submitTimelock(timelock);
    }

    function testAcceptTimelock(uint192 timelock) public {
        timelock = uint192(bound(timelock, 0, MAX_TIMELOCK));

        vm.assume(timelock != vault.timelock());

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + vault.timelock());

        vm.prank(OWNER);
        vault.acceptTimelock();

        assertEq(vault.timelock(), timelock);
    }

    function testAcceptTimelockNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.acceptTimelock();
    }

    function testAcceptTimelockNotElapsed(uint192 currTimelock, uint192 newTimelock, uint256 elapsed) public {
        currTimelock = uint192(bound(currTimelock, 2, MAX_TIMELOCK));
        newTimelock = uint192(bound(newTimelock, 0, MAX_TIMELOCK));
        elapsed = bound(elapsed, 1, currTimelock - 1);

        vm.assume(currTimelock != vault.timelock());

        _setTimelock(currTimelock);

        vm.prank(OWNER);
        vault.submitTimelock(newTimelock);

        vm.warp(block.timestamp + elapsed);

        vm.prank(OWNER);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_NOT_ELAPSED));
        vault.acceptTimelock();
    }

    function testAcceptTimelockExpirationExceeded(uint192 currTimelock, uint192 newTimelock, uint256 elapsed) public {
        currTimelock = uint192(bound(currTimelock, 1, MAX_TIMELOCK));
        newTimelock = uint192(bound(newTimelock, 0, MAX_TIMELOCK));
        elapsed = bound(elapsed, currTimelock + TIMELOCK_EXPIRATION + 1, type(uint64).max);

        vm.assume(currTimelock != vault.timelock());

        _setTimelock(currTimelock);

        vm.prank(OWNER);
        vault.submitTimelock(newTimelock);

        vm.warp(block.timestamp + elapsed);

        vm.prank(OWNER);
        vm.expectRevert(bytes(ErrorsLib.TIMELOCK_EXPIRATION_EXCEEDED));
        vault.acceptTimelock();
    }
}
