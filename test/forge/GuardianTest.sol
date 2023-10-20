// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/IntegrationTest.sol";

uint256 constant FEE = 0.1 ether; // 10%
uint256 constant TIMELOCK = 1 weeks;

contract GuardianTest is IntegrationTest {
    using Math for uint256;
    using MathLib for uint256;
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

        vm.prank(OWNER);
        vault.setFeeRecipient(FEE_RECIPIENT);

        _setFee(FEE);
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

    function testGuardianRevokeTimelockDecreased(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit();
        emit EventsLib.RevokeTimelock(GUARDIAN, IPending(address(vault)).pendingTimelock());
        vm.prank(GUARDIAN);
        vault.revokeTimelock();

        uint256 newTimelock = vault.timelock();
        (uint256 pendingTimelock, uint64 submittedAt) = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock, 0, "pendingTimelock");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testOwnerRevokeTimelockDecreased(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit();
        emit EventsLib.RevokeTimelock(OWNER, IPending(address(vault)).pendingTimelock());
        vm.prank(OWNER);
        vault.revokeTimelock();

        uint256 newTimelock = vault.timelock();
        (uint256 pendingTimelock, uint64 submittedAt) = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock, 0, "pendingTimelock");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testGuardianRevokeCapIncreased(uint256 seed, uint256 cap, uint256 elapsed) public {
        MarketParams memory marketParams = _randomMarketParams(seed);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);
        cap = bound(cap, 1, type(uint192).max);

        vm.prank(OWNER);
        vault.submitCap(marketParams, cap);

        vm.warp(block.timestamp + elapsed);

        Id id = marketParams.id();

        vm.expectEmit();
        emit EventsLib.RevokeCap(GUARDIAN, id, IPending(address(vault)).pendingCap(id));
        vm.prank(GUARDIAN);
        vault.revokeCap(id);

        (uint192 newCap, uint64 withdrawRank) = vault.config(id);
        (uint256 pendingCap, uint64 submittedAt) = vault.pendingCap(id);

        assertEq(newCap, 0, "newCap");
        assertEq(withdrawRank, 0, "withdrawRank");
        assertEq(pendingCap, 0, "pendingCap");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testCuratorRevokeCapIncreased(uint256 seed, uint256 cap, uint256 elapsed) public {
        MarketParams memory marketParams = _randomMarketParams(seed);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);
        cap = bound(cap, 1, type(uint192).max);

        vm.prank(OWNER);
        vault.submitCap(marketParams, cap);

        vm.warp(block.timestamp + elapsed);

        Id id = marketParams.id();

        vm.expectEmit();
        emit EventsLib.RevokeCap(CURATOR, id, IPending(address(vault)).pendingCap(id));
        vm.prank(CURATOR);
        vault.revokeCap(id);

        (uint192 newCap, uint64 withdrawRank) = vault.config(id);
        (uint256 pendingCap, uint64 submittedAt) = vault.pendingCap(id);

        assertEq(newCap, 0, "newCap");
        assertEq(withdrawRank, 0, "withdrawRank");
        assertEq(pendingCap, 0, "pendingCap");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testOwnerRevokeCapIncreased(uint256 seed, uint256 cap, uint256 elapsed) public {
        MarketParams memory marketParams = _randomMarketParams(seed);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);
        cap = bound(cap, 1, type(uint192).max);

        vm.prank(OWNER);
        vault.submitCap(marketParams, cap);

        vm.warp(block.timestamp + elapsed);

        Id id = marketParams.id();

        vm.expectEmit();
        emit EventsLib.RevokeCap(OWNER, id, IPending(address(vault)).pendingCap(id));
        vm.prank(OWNER);
        vault.revokeCap(id);

        (uint192 newCap, uint64 withdrawRank) = vault.config(id);
        (uint256 pendingCap, uint64 submittedAt) = vault.pendingCap(id);

        assertEq(newCap, 0, "newCap");
        assertEq(withdrawRank, 0, "withdrawRank");
        assertEq(pendingCap, 0, "pendingCap");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testGuardianRevokeGuardian(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit();
        emit EventsLib.RevokeGuardian(GUARDIAN, IPending(address(vault)).pendingGuardian());
        vm.prank(GUARDIAN);
        vault.revokeGuardian();

        address newGuardian = vault.guardian();
        (address pendingGuardian, uint96 submittedAt) = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian, address(0), "pendingGuardian");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testOwnerRevokeGuardian(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.NotGuardian.selector);
        vm.prank(OWNER);
        vault.revokeGuardian();
    }

    function testOwnerRevokeFeeIncreased(uint256 fee, uint256 elapsed) public {
        fee = bound(fee, FEE + 1, ConstantsLib.MAX_FEE);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitFee(fee);

        vm.warp(block.timestamp + elapsed);

        vm.expectEmit();
        emit EventsLib.RevokeFee(OWNER, IPending(address(vault)).pendingFee());
        vm.prank(OWNER);
        vault.revokeFee();

        uint256 newFee = vault.fee();
        (uint256 pendingFee, uint64 submittedAt) = vault.pendingFee();

        assertEq(newFee, FEE, "newFee");
        assertEq(pendingFee, 0, "pendingFee");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testGuardianRevokeFeeIncreased(uint256 fee, uint256 elapsed) public {
        fee = bound(fee, FEE + 1, ConstantsLib.MAX_FEE);
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitFee(fee);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, GUARDIAN));
        vm.prank(GUARDIAN);
        vault.revokeFee();
    }
}
