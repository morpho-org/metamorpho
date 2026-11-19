// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/IntegrationTest.sol";

contract GuardianTest is IntegrationTest {
    using Math for uint256;
    using MathLib for uint256;
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

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

    function testGuardianRevokePendingTimelockDecreased(uint256 timelock, uint256 elapsed) public {
        timelock = _boundTimelock(timelock);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit(address(vault));
        emit EventsLib.RevokePendingTimelock(GUARDIAN);
        vm.prank(GUARDIAN);
        vault.revokePendingTimelock();

        uint256 newTimelock = vault.timelock();
        PendingUint192 memory pendingTimelock = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock.value, 0, "pendingTimelock.value");
        assertEq(pendingTimelock.validAt, 0, "pendingTimelock.validAt");
    }

    function testOwnerRevokePendingTimelockDecreased(uint256 timelock, uint256 elapsed) public {
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

    function testGuardianRevokePendingCapIncreased(uint256 seed, uint256 cap, uint256 elapsed) public {
        MarketParams memory marketParams = _randomMarketParams(seed);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);
        cap = bound(cap, 1, type(uint184).max);

        vm.prank(OWNER);
        vault.submitCap(marketParams, cap);

        vm.warp(block.timestamp + elapsed);

        Id id = marketParams.id();

        vm.expectEmit(address(vault));
        emit EventsLib.RevokePendingCap(GUARDIAN, id);
        vm.prank(GUARDIAN);
        vault.revokePendingCap(id);

        MarketConfig memory marketConfig = vault.config(id);
        PendingUint192 memory pendingCap = vault.pendingCap(id);

        assertEq(marketConfig.cap, 0, "marketConfig.cap");
        assertEq(marketConfig.enabled, false, "marketConfig.enabled");
        assertEq(marketConfig.removableAt, 0, "marketConfig.removableAt");
        assertEq(pendingCap.value, 0, "pendingCap.value");
        assertEq(pendingCap.validAt, 0, "pendingCap.validAt");
    }

    function testGuardianRevokePendingGuardian(uint256 elapsed) public {
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
        PendingAddress memory pendingGuardian = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian.value, address(0), "pendingGuardian.value");
        assertEq(pendingGuardian.validAt, 0, "pendingGuardian.validAt");
    }

    function testRevokePendingMarketRemoval(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        MarketParams memory marketParams = allMarkets[0];
        Id id = marketParams.id();

        _setCap(marketParams, CAP);
        _setCap(marketParams, 0);

        vm.prank(CURATOR);
        vault.submitMarketRemoval(allMarkets[0]);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit(address(vault));
        emit EventsLib.RevokePendingMarketRemoval(GUARDIAN, id);
        vm.prank(GUARDIAN);
        vault.revokePendingMarketRemoval(id);

        MarketConfig memory marketConfig = vault.config(id);

        assertEq(marketConfig.cap, 0, "marketConfig.cap");
        assertEq(marketConfig.enabled, true, "marketConfig.enabled");
        assertEq(marketConfig.removableAt, 0, "marketConfig.removableAt");
    }
}
