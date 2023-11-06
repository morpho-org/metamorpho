// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/IntegrationTest.sol";

uint256 constant TIMELOCK = 1 weeks;

contract GuardianTest is IntegrationTest {
    using Math for uint256;
    using MathLib for uint256;
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

        _setTimelock(TIMELOCK);
        _setGuardian(GUARDIAN);
    }

    function testSubmitGuardianNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.submitGuardian(GUARDIAN);
    }

    function testSubmitGuardianAlreadySet() public {
        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.submitGuardian(GUARDIAN);
    }

    function testRevokePendingTimelockDecreased(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit(address(vault));
        emit EventsLib.RevokePendingTimelock(GUARDIAN);
        vm.prank(GUARDIAN);
        vault.revokePendingTimelock();

        uint256 newTimelock = vault.timelock();
        (uint256 pendingTimelock, uint64 submittedAt) = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock, 0, "pendingTimelock");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testRevokePendingCapIncreased(uint256 seed, uint256 cap, uint256 elapsed) public {
        MarketParams memory marketParams = _randomMarketParams(seed);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);
        cap = bound(cap, 1, type(uint192).max);

        vm.prank(OWNER);
        vault.submitCap(marketParams, cap);

        vm.warp(block.timestamp + elapsed);

        Id id = marketParams.id();

        vm.expectEmit(address(vault));
        emit EventsLib.RevokePendingCap(GUARDIAN, id);
        vm.prank(GUARDIAN);
        vault.revokePendingCap(id);

        (uint192 newCap, uint64 withdrawRank) = vault.config(id);
        (uint256 pendingCap, uint64 submittedAt) = vault.pendingCap(id);

        assertEq(newCap, 0, "newCap");
        assertEq(withdrawRank, 0, "withdrawRank");
        assertEq(pendingCap, 0, "pendingCap");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testRevokePendingGuardian(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit(address(vault));
        emit EventsLib.RevokePendingGuardian(GUARDIAN);
        vm.prank(GUARDIAN);
        vault.revokePendingGuardian();

        address newGuardian = vault.guardian();
        (address pendingGuardian, uint96 submittedAt) = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian, address(0), "pendingGuardian");
        assertEq(submittedAt, 0, "submittedAt");
    }
}
