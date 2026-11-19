// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/IntegrationTest.sol";

uint256 constant FEE = 0.1 ether; // 10%

contract RevokeTest is IntegrationTest {
    using Math for uint256;
    using MathLib for uint256;
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

        _setFee(FEE);
        _setGuardian(GUARDIAN);
    }

    function testOwnerRevokeTimelockDecreased(uint256 timelock, uint256 elapsed) public {
        timelock = _boundTimelock(timelock);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit();
        emit EventsLib.RevokePendingTimelock(OWNER);
        vm.prank(OWNER);
        vault.revokePendingTimelock();

        uint256 newTimelock = vault.timelock();
        PendingUint192 memory pendingTimelock = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock.value, 0, "value");
        assertEq(pendingTimelock.validAt, 0, "validAt");
    }

    function testCuratorRevokeCapIncreased(uint256 seed, uint256 cap, uint256 elapsed) public {
        MarketParams memory marketParams = _randomMarketParams(seed);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);
        cap = bound(cap, 1, type(uint184).max);

        vm.prank(OWNER);
        vault.submitCap(marketParams, cap);

        vm.warp(block.timestamp + elapsed);

        Id id = marketParams.id();

        vm.expectEmit();
        emit EventsLib.RevokePendingCap(CURATOR, id);
        vm.prank(CURATOR);
        vault.revokePendingCap(id);

        MarketConfig memory marketConfig = vault.config(id);
        PendingUint192 memory pendingCap = vault.pendingCap(id);

        assertEq(marketConfig.cap, 0, "cap");
        assertEq(marketConfig.enabled, false, "enabled");
        assertEq(marketConfig.removableAt, 0, "removableAt");
        assertEq(pendingCap.value, 0, "value");
        assertEq(pendingCap.validAt, 0, "validAt");
    }

    function testOwnerRevokeCapIncreased(uint256 seed, uint256 cap, uint256 elapsed) public {
        MarketParams memory marketParams = _randomMarketParams(seed);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);
        cap = bound(cap, 1, type(uint184).max);

        vm.prank(OWNER);
        vault.submitCap(marketParams, cap);

        vm.warp(block.timestamp + elapsed);

        Id id = marketParams.id();

        vm.expectEmit();
        emit EventsLib.RevokePendingCap(OWNER, id);
        vm.prank(OWNER);
        vault.revokePendingCap(id);

        MarketConfig memory marketConfig = vault.config(id);
        PendingUint192 memory pendingCap = vault.pendingCap(id);

        assertEq(marketConfig.cap, 0, "cap");
        assertEq(marketConfig.enabled, false, "enabled");
        assertEq(marketConfig.removableAt, 0, "removableAt");
        assertEq(pendingCap.value, 0, "value");
        assertEq(pendingCap.validAt, 0, "validAt");
    }

    function testOwnerRevokeGuardian(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit();
        emit EventsLib.RevokePendingGuardian(GUARDIAN);
        vm.prank(GUARDIAN);
        vault.revokePendingGuardian();

        address newGuardian = vault.guardian();
        PendingAddress memory pendingGuardian = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian.value, address(0), "value");
        assertEq(pendingGuardian.validAt, 0, "validAt");
    }
}
