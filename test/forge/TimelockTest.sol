// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/IntegrationTest.sol";

uint256 constant FEE = 0.1 ether; // 10%
uint256 constant TIMELOCK = 1 weeks;

contract TimelockTest is IntegrationTest {
    using MarketParamsLib for MarketParams;

    function setUp() public override {
        super.setUp();

        vm.prank(OWNER);
        vault.setFeeRecipient(FEE_RECIPIENT);

        _setFee(FEE);
        _setTimelock(TIMELOCK);
        _setGuardian(GUARDIAN);

        _setCap(allMarkets[0], CAP);
    }

    function testSubmitTimelockIncreased(uint256 timelock) public {
        timelock = bound(timelock, TIMELOCK + 1, ConstantsLib.MAX_TIMELOCK);

        vm.expectEmit();
        emit EventsLib.SetTimelock(timelock);
        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        uint256 newTimelock = vault.timelock();
        (uint256 pendingTimelock, uint64 submittedAt) = vault.pendingTimelock();

        assertEq(newTimelock, timelock, "newTimelock");
        assertEq(pendingTimelock, 0, "pendingTimelock");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testSubmitTimelockDecreased(uint256 timelock) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);

        vm.expectEmit();
        emit EventsLib.SubmitTimelock(timelock);
        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        uint256 newTimelock = vault.timelock();
        (uint256 pendingTimelock, uint64 submittedAt) = vault.pendingTimelock();

        assertEq(newTimelock, TIMELOCK, "newTimelock");
        assertEq(pendingTimelock, timelock, "pendingTimelock");
        assertEq(submittedAt, block.timestamp, "submittedAt");
    }

    function testSubmitTimelockNotOwner(uint256 timelock) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        vault.submitTimelock(timelock);
    }

    function testDeployMetaMorphoAboveMaxTimelock(uint256 timelock) public {
        timelock = bound(timelock, ConstantsLib.MAX_TIMELOCK + 1, type(uint256).max);

        vm.expectRevert(ErrorsLib.AboveMaxTimelock.selector);
        new MetaMorpho(OWNER, address(morpho), timelock, address(loanToken), "MetaMorpho Vault", "MMV");
    }

    function testDeployMetaMorphoBelowMinTimelock(uint256 timelock) public {
        timelock = bound(timelock, 0, ConstantsLib.MIN_TIMELOCK - 1);

        vm.expectRevert(ErrorsLib.BelowMinTimelock.selector);
        new MetaMorpho(OWNER, address(morpho), timelock, address(loanToken), "MetaMorpho Vault", "MMV");
    }

    function testSubmitTimelockAboveMaxTimelock(uint256 timelock) public {
        timelock = bound(timelock, ConstantsLib.MAX_TIMELOCK + 1, type(uint256).max);

        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AboveMaxTimelock.selector);
        vault.submitTimelock(timelock);
    }

    function testSubmitTimelockBelowMinTimelock(uint256 timelock) public {
        timelock = bound(timelock, 0, ConstantsLib.MIN_TIMELOCK - 1);

        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.BelowMinTimelock.selector);
        vault.submitTimelock(timelock);
    }

    function testSubmitTimelockAlreadySet() public {
        uint256 timelock = vault.timelock();

        vm.prank(OWNER);
        vm.expectRevert(ErrorsLib.AlreadySet.selector);
        vault.submitTimelock(timelock);
    }

    function testAcceptTimelock(uint256 timelock) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + TIMELOCK);

        vm.expectEmit();
        emit EventsLib.SetTimelock(timelock);
        vault.acceptTimelock();

        uint256 newTimelock = vault.timelock();
        (uint256 pendingTimelock, uint64 submittedAt) = vault.pendingTimelock();

        assertEq(newTimelock, timelock, "newTimelock");
        assertEq(pendingTimelock, 0, "pendingTimelock");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testAcceptTimelockNoPendingValue() public {
        vm.expectRevert(ErrorsLib.NoPendingValue.selector);
        vault.acceptTimelock();
    }

    function testAcceptTimelockTimelockNotElapsed(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);
        elapsed = bound(elapsed, 1, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.TimelockNotElapsed.selector);
        vault.acceptTimelock();
    }

    function testAcceptTimelockTimelockExpirationExceeded(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, TIMELOCK - 1);
        elapsed = bound(elapsed, TIMELOCK + ConstantsLib.TIMELOCK_EXPIRATION + 1, type(uint64).max);

        vm.prank(OWNER);
        vault.submitTimelock(timelock);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.TimelockExpirationExceeded.selector);
        vault.acceptTimelock();
    }

    function testSubmitFeeDecreased(uint256 fee) public {
        fee = bound(fee, 0, FEE - 1);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets());
        vm.expectEmit();
        emit EventsLib.SetFee(fee);
        vm.prank(OWNER);
        vault.submitFee(fee);

        uint256 newFee = vault.fee();
        (uint256 pendingFee, uint64 submittedAt) = vault.pendingFee();

        assertEq(newFee, fee, "newFee");
        assertEq(pendingFee, 0, "pendingFee");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testSubmitFeeIncreased(uint256 fee) public {
        fee = bound(fee, FEE + 1, ConstantsLib.MAX_FEE);

        vm.expectEmit();
        emit EventsLib.SubmitFee(fee);
        vm.prank(OWNER);
        vault.submitFee(fee);

        uint256 newFee = vault.fee();
        (uint256 pendingFee, uint64 submittedAt) = vault.pendingFee();

        assertEq(newFee, FEE, "newFee");
        assertEq(pendingFee, fee, "pendingFee");
        assertEq(submittedAt, block.timestamp, "submittedAt");
    }

    function testAcceptFee(uint256 fee) public {
        fee = bound(fee, FEE + 1, ConstantsLib.MAX_FEE);

        vm.prank(OWNER);
        vault.submitFee(fee);

        vm.warp(block.timestamp + TIMELOCK);

        vm.expectEmit();
        emit EventsLib.UpdateLastTotalAssets(vault.totalAssets());
        vm.expectEmit();
        emit EventsLib.SetFee(fee);
        vault.acceptFee();

        uint256 newFee = vault.fee();
        (uint256 pendingFee, uint64 submittedAt) = vault.pendingFee();

        assertEq(newFee, fee, "newFee");
        assertEq(pendingFee, 0, "pendingFee");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testAcceptFeeNoPendingValue() public {
        vm.expectRevert(ErrorsLib.NoPendingValue.selector);
        vault.acceptFee();
    }

    function testAcceptFeeTimelockNotElapsed(uint256 fee, uint256 elapsed) public {
        fee = bound(fee, FEE + 1, ConstantsLib.MAX_FEE);
        elapsed = bound(elapsed, 1, TIMELOCK - 1);

        vm.prank(OWNER);
        vault.submitFee(fee);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.TimelockNotElapsed.selector);
        vault.acceptFee();
    }

    function testAcceptFeeTimelockExpirationExceeded(uint256 fee, uint256 elapsed) public {
        fee = bound(fee, FEE + 1, ConstantsLib.MAX_FEE);
        elapsed = bound(elapsed, TIMELOCK + ConstantsLib.TIMELOCK_EXPIRATION + 1, type(uint64).max);

        vm.prank(OWNER);
        vault.submitFee(fee);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.TimelockExpirationExceeded.selector);
        vault.acceptFee();
    }

    function testSubmitGuardian() public {
        address guardian = makeAddr("Guardian2");

        vm.expectEmit();
        emit EventsLib.SubmitGuardian(guardian);
        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        address newGuardian = vault.guardian();
        (address pendingGuardian, uint96 submittedAt) = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian, guardian, "pendingGuardian");
        assertEq(submittedAt, block.timestamp, "submittedAt");
    }

    function testSubmitGuardianFromZero() public {
        _setGuardian(address(0));

        vm.expectEmit();
        emit EventsLib.SetGuardian(GUARDIAN);
        vm.prank(OWNER);
        vault.submitGuardian(GUARDIAN);

        address newGuardian = vault.guardian();
        (address pendingGuardian, uint96 submittedAt) = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian, address(0), "pendingGuardian");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testSubmitGuardianZero() public {
        vm.prank(OWNER);
        vault.submitGuardian(address(0));

        address newGuardian = vault.guardian();
        (address pendingGuardian, uint96 submittedAt) = vault.pendingGuardian();

        assertEq(newGuardian, GUARDIAN, "newGuardian");
        assertEq(pendingGuardian, address(0), "pendingGuardian");
        assertEq(submittedAt, block.timestamp, "submittedAt");
    }

    function testAcceptGuardian() public {
        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + TIMELOCK);

        vm.expectEmit();
        emit EventsLib.SetGuardian(guardian);
        vault.acceptGuardian();

        address newGuardian = vault.guardian();
        (address pendingGuardian, uint96 submittedAt) = vault.pendingGuardian();

        assertEq(newGuardian, guardian, "newGuardian");
        assertEq(pendingGuardian, address(0), "pendingGuardian");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testAcceptGuardianNoPendingValue() public {
        vm.expectRevert(ErrorsLib.NoPendingValue.selector);
        vault.acceptGuardian();
    }

    function testAcceptGuardianTimelockNotElapsed(uint256 elapsed) public {
        elapsed = bound(elapsed, 1, TIMELOCK - 1);

        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.TimelockNotElapsed.selector);
        vault.acceptGuardian();
    }

    function testAcceptGuardianTimelockExpirationExceeded(uint256 elapsed) public {
        elapsed = bound(elapsed, TIMELOCK + ConstantsLib.TIMELOCK_EXPIRATION + 1, type(uint64).max);

        address guardian = makeAddr("Guardian2");

        vm.prank(OWNER);
        vault.submitGuardian(guardian);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.TimelockExpirationExceeded.selector);
        vault.acceptGuardian();
    }

    function testSubmitCapDecreased(uint256 cap) public {
        cap = bound(cap, 0, CAP - 1);

        MarketParams memory marketParams = allMarkets[0];
        Id id = marketParams.id();

        vm.expectEmit();
        emit EventsLib.SetCap(id, cap);
        vm.prank(CURATOR);
        vault.submitCap(marketParams, cap);

        (uint192 newCap, uint64 withdrawRank) = vault.config(id);
        (uint192 pendingCap, uint64 submittedAt) = vault.pendingCap(id);

        assertEq(newCap, cap, "newCap");
        assertEq(withdrawRank, 1, "withdrawRank");
        assertEq(pendingCap, 0, "pendingCap");
        assertEq(submittedAt, 0, "submittedAt");
    }

    function testSubmitCapIncreased(uint256 cap) public {
        cap = bound(cap, 1, type(uint192).max);

        MarketParams memory marketParams = allMarkets[1];
        Id id = marketParams.id();

        vm.expectEmit();
        emit EventsLib.SubmitCap(id, cap);
        vm.prank(CURATOR);
        vault.submitCap(marketParams, cap);

        (uint192 newCap, uint64 withdrawRank) = vault.config(id);
        (uint192 pendingCap, uint64 submittedAt) = vault.pendingCap(id);

        assertEq(newCap, 0, "newCap");
        assertEq(withdrawRank, 0, "withdrawRank");
        assertEq(pendingCap, cap, "pendingCap");
        assertEq(submittedAt, block.timestamp, "submittedAt");
        assertEq(vault.supplyQueueSize(), 1, "supplyQueueSize");
        assertEq(vault.withdrawQueueSize(), 1, "withdrawQueueSize");
    }

    function testAcceptCapIncreased(uint256 cap) public {
        cap = bound(cap, CAP + 1, type(uint192).max);

        MarketParams memory marketParams = allMarkets[0];
        Id id = marketParams.id();

        vm.prank(CURATOR);
        vault.submitCap(marketParams, cap);

        vm.warp(block.timestamp + TIMELOCK);

        vm.expectEmit();
        emit EventsLib.SetCap(id, cap);
        vault.acceptCap(id);

        (uint192 newCap, uint64 withdrawRank) = vault.config(id);
        (uint192 pendingCapAfter, uint64 submittedAtAfter) = vault.pendingCap(id);

        assertEq(newCap, cap, "newCap");
        assertEq(withdrawRank, 1, "withdrawRank");
        assertEq(pendingCapAfter, 0, "pendingCapAfter");
        assertEq(submittedAtAfter, 0, "submittedAtAfter");
        assertEq(Id.unwrap(vault.supplyQueue(0)), Id.unwrap(id), "supplyQueue");
        assertEq(Id.unwrap(vault.withdrawQueue(0)), Id.unwrap(id), "withdrawQueue");
    }

    function testAcceptCapNoPendingValue() public {
        vm.expectRevert(ErrorsLib.NoPendingValue.selector);
        vault.acceptCap(allMarkets[0].id());
    }

    function testAcceptCapTimelockNotElapsed(uint256 elapsed) public {
        elapsed = bound(elapsed, 0, TIMELOCK - 1);

        vm.prank(CURATOR);
        vault.submitCap(allMarkets[1], CAP);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.TimelockNotElapsed.selector);
        vault.acceptCap(allMarkets[1].id());
    }

    function testAcceptCapTimelockExpirationExceeded(uint256 timelock, uint256 elapsed) public {
        timelock = bound(timelock, ConstantsLib.MIN_TIMELOCK, ConstantsLib.MAX_TIMELOCK);

        vm.assume(timelock != vault.timelock());

        _setTimelock(timelock);

        elapsed = bound(elapsed, timelock + ConstantsLib.TIMELOCK_EXPIRATION + 1, type(uint64).max);

        vm.startPrank(CURATOR);
        vault.submitCap(allMarkets[1], CAP);

        vm.warp(block.timestamp + elapsed);

        vm.expectRevert(ErrorsLib.TimelockExpirationExceeded.selector);
        vault.acceptCap(allMarkets[1].id());
    }
}
