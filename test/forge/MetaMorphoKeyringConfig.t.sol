// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import "./helpers/InternalTest.sol";
import {IKeyringChecker} from "../../src/interfaces/IKeyringChecker.sol";
import {EventsLib} from "../../src/libraries/EventsLib.sol";

contract MockKeyringChecker is IKeyringChecker {
    function checkCredential(uint256, address) external pure returns (bool) {
        return true;
    }
}

contract MetaMorphoSetKeyringConfigTest is InternalTest {
    MockKeyringChecker public mockKeyringChecker;

    function setUp() public override {
        super.setUp();
        mockKeyringChecker = new MockKeyringChecker();
    }

    function testSetKeyringConfig() public {
        vm.startPrank(OWNER);

        uint256 policyId = 123;

        vm.expectEmit(true, true, false, true);
        emit EventsLib.SetKeyringConfig(mockKeyringChecker, policyId);

        this.setKeyringConfig(mockKeyringChecker, policyId);

        vm.stopPrank();
    }

    function testSetKeyringConfigOnlyOwner() public {
        address nonOwner = makeAddr("nonOwner");
        vm.startPrank(nonOwner);

        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        this.setKeyringConfig(mockKeyringChecker, 123);

        vm.stopPrank();
    }

    function testSetKeyringConfigZeroAddress() public {
        vm.startPrank(OWNER);

        uint256 policyId = 123;

        vm.expectEmit(true, true, false, true);
        emit EventsLib.SetKeyringConfig(IKeyringChecker(address(0)), policyId);

        this.setKeyringConfig(IKeyringChecker(address(0)), policyId);

        vm.stopPrank();
    }

    function testSetKeyringConfigMultipleTimes() public {
        vm.startPrank(OWNER);

        // First configuration
        uint256 firstPolicyId = 123;
        this.setKeyringConfig(mockKeyringChecker, firstPolicyId);

        // Second configuration
        uint256 secondPolicyId = 456;
        MockKeyringChecker newMockChecker = new MockKeyringChecker();

        vm.expectEmit(true, true, false, true);
        emit EventsLib.SetKeyringConfig(newMockChecker, secondPolicyId);

        this.setKeyringConfig(newMockChecker, secondPolicyId);

        vm.stopPrank();
    }
}
