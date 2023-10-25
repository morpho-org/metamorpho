// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract IntegrationTest is BaseTest {
    using MathLib for uint256;
    using MarketParamsLib for MarketParams;

    MetaMorpho internal vault;

    function setUp() public virtual override {
        super.setUp();

        vault =
        new MetaMorpho(OWNER, address(morpho), ConstantsLib.MIN_TIMELOCK, address(loanToken), "MetaMorpho Vault", "MMV");

        vm.startPrank(OWNER);
        vault.setCurator(CURATOR);
        vault.setIsAllocator(ALLOCATOR, true);
        vm.stopPrank();

        loanToken.approve(address(vault), type(uint256).max);
        collateralToken.approve(address(vault), type(uint256).max);

        vm.startPrank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);
        collateralToken.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(ONBEHALF);
        loanToken.approve(address(vault), type(uint256).max);
        collateralToken.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function _setTimelock(uint256 newTimelock) internal {
        uint256 timelock = vault.timelock();
        if (newTimelock == timelock) return;

        // block.timestamp defaults to 1 which may lead to an unrealistic state: block.timestamp < timelock.
        if (block.timestamp < timelock) vm.warp(block.timestamp + timelock);

        vm.prank(OWNER);
        vault.submitTimelock(newTimelock);

        if (newTimelock > timelock || timelock == 0) return;

        vm.warp(block.timestamp + timelock);

        vault.acceptTimelock();

        assertEq(vault.timelock(), newTimelock, "_setTimelock");
    }

    function _setGuardian(address newGuardian) internal {
        address guardian = vault.guardian();
        if (newGuardian == guardian) return;

        vm.prank(OWNER);
        vault.submitGuardian(newGuardian);

        uint256 timelock = vault.timelock();
        if (guardian == address(0) || timelock == 0) return;

        vm.warp(block.timestamp + timelock);

        vault.acceptGuardian();

        assertEq(vault.guardian(), newGuardian, "_setGuardian");
    }

    function _setFee(uint256 newFee) internal {
        uint256 fee = vault.fee();
        if (newFee == fee) return;

        vm.prank(OWNER);
        vault.submitFee(newFee);

        uint256 timelock = vault.timelock();
        if (newFee < fee || timelock == 0) return;

        vm.warp(block.timestamp + timelock);

        vault.acceptFee();

        assertEq(vault.fee(), newFee, "_setFee");
    }

    function _setCap(MarketParams memory marketParams, uint256 newCap) internal {
        Id id = marketParams.id();
        (uint256 cap,) = vault.config(id);
        if (newCap == cap) return;

        vm.prank(CURATOR);
        vault.submitCap(marketParams, newCap);

        uint256 timelock = vault.timelock();
        if (newCap < cap) return;

        vm.warp(block.timestamp + timelock);

        vault.acceptCap(id);

        (cap,) = vault.config(id);

        assertEq(cap, newCap, "_setCap");
    }
}
