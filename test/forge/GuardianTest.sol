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

    function testRevokeTimelockDecreased(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit();
        emit EventsLib.RevokeTimelock(GUARDIAN, vault.pendingTimelock());
        vm.prank(GUARDIAN);
        vault.revokeTimelock();

        uint256 newTimelock = vault.timelock();
        PendingUint192 memory pendingTimelock = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock.value, 0, "pendingTimelock.value");
        assertEq(pendingTimelock.submittedAt, 0, "pendingTimelock.submittedAt");
    }

    function testRevokeCapIncreased(uint256 seed, uint256 cap, uint256 elapsed) public {
        MarketParams memory marketParams = _randomMarketParams(seed);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);
        cap = bound(cap, 1, type(uint192).max);

        vm.prank(OWNER);
        vault.submitCap(marketParams, cap);

        vm.warp(block.timestamp + elapsed);

        Id id = marketParams.id();

        vm.expectEmit();
        emit EventsLib.RevokeCap(GUARDIAN, id, vault.pendingCap(id));
        vm.prank(GUARDIAN);
        vault.revokeCap(id);

        MarketConfig memory marketConfig = vault.config(id);
        PendingUint192 memory pendingCap = vault.pendingCap(id);

        assertEq(marketConfig.cap, 0, "marketConfig.cap");
        assertEq(marketConfig.withdrawRank, 0, "marketConfig.withdrawRank");
        assertEq(pendingCap.value, 0, "pendingCap.value");
        assertEq(pendingCap.submittedAt, 0, "pendingCap.submittedAt");
    }

    function testRevokeGuardian(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit();
        emit EventsLib.RevokeGuardian(GUARDIAN, vault.pendingGuardian());
        vm.prank(GUARDIAN);
        vault.revokeGuardian();

        address newGuardian = vault.guardian();
        PendingAddress memory pendingGuardian = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian.value, address(0), "pendingGuardian.value");
        assertEq(pendingGuardian.submittedAt, 0, "pendingGuardian.submittedAt");
    }
}
