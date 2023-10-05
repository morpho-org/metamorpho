// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/BaseTest.sol";

uint256 constant TIMELOCK = 1 weeks;

contract GuardianTest is BaseTest {
    using Math for uint256;
    using MathLib for uint256;
    using MarketParamsLib for MarketParams;

    address internal GUARDIAN;

    function setUp() public override {
        super.setUp();

        GUARDIAN = _addrFromHashedString("Guardian");

        // block.timestamp defaults to 1 which is an unrealistic state: block.timestamp < TIMELOCK.
        vm.warp(block.timestamp + TIMELOCK);

        _setTimelock(TIMELOCK);
        _setGuardian(GUARDIAN);
    }

    function testSubmitGuardianNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vault.submitGuardian(GUARDIAN);
    }

    function testSubmitGuardianAlreadySet() public {
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.submitGuardian(GUARDIAN);
    }

    function testRevokeTimelockDecreased(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, 0, TIMELOCK - 1);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.prank(GUARDIAN);
        vault.revokeTimelock();

        uint256 newTimelock = vault.timelock();
        (uint256 pendingTimelock, uint64 submittedAt) = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock, 0, "pendingTimelock");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testRevokeCapIncreased(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, 0, TIMELOCK - 1);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.prank(GUARDIAN);
        vault.revokeTimelock();

        uint256 newTimelock = vault.timelock();
        (uint256 pendingTimelock, uint64 submittedAt) = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock, 0, "pendingTimelock");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testRevokeGuardian(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        address guardian = _addrFromHashedString("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + elapsed);

        vm.prank(GUARDIAN);
        vault.revokeGuardian();

        address newGuardian = vault.guardian();
        (address pendingGuardian, uint96 submittedAt) = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian, address(0), "pendingGuardian");
        assertEq(submittedAt, 0, "submittedAt");
    }
}
