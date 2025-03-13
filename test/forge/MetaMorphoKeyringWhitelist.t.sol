// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {UtilsLib} from "../../lib/morpho-blue/src/libraries/UtilsLib.sol";
import {SharesMathLib} from "../../lib/morpho-blue/src/libraries/SharesMathLib.sol";

import "./helpers/IntegrationTest.sol";
import {IKeyringChecker} from "../../src/interfaces/IKeyringChecker.sol";
import {ErrorsLib} from "../../src/libraries/ErrorsLib.sol";

contract MockKeyringChecker is IKeyringChecker {
    mapping(address => bool) public isWhitelisted;

    function setWhitelisted(address user, bool status) external {
        isWhitelisted[user] = status;
    }

    function checkCredential(uint256, address user) external view returns (bool) {
        return isWhitelisted[user];
    }
}

contract MetaMorphoKeyringWhitelist is IntegrationTest {
    using MathLib for uint256;
    using MarketParamsLib for MarketParams;
    using MorphoLib for IMorpho;

    MockKeyringChecker public keyringChecker;
    uint256 public constant POLICY_ID = 1;
    address public whitelistedUser;
    address public nonWhitelistedUser;
    uint256 public constant INITIAL_DEPOSIT = 1000e18;

    function setUp() public override {
        super.setUp();

        // Setup market caps first (following MarketTest pattern)
        _setCap(allMarkets[0], CAP);
        _setCap(allMarkets[1], CAP);
        _setCap(allMarkets[2], CAP);

        // Setup users
        whitelistedUser = makeAddr("whitelistedUser");
        nonWhitelistedUser = makeAddr("nonWhitelistedUser");

        // Setup keyring checker
        keyringChecker = new MockKeyringChecker();
        keyringChecker.setWhitelisted(whitelistedUser, true);

        // Configure keyring on vault
        vm.prank(OWNER);
        vault.setKeyringConfig(keyringChecker, POLICY_ID);

        // Set supply queue (following MarketTest pattern)
        Id[] memory supplyQueue = new Id[](1);
        supplyQueue[0] = allMarkets[0].id();

        vm.prank(ALLOCATOR);
        vault.setSupplyQueue(supplyQueue);
    }

    function test_whitelistedUserCanDeposit() public {
        loanToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);
        vm.startPrank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);
        vault.deposit(INITIAL_DEPOSIT, whitelistedUser);
        assertEq(vault.balanceOf(whitelistedUser), INITIAL_DEPOSIT);
    }

    function test_nonWhitelistedUserCannotDeposit() public {
        loanToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);
        vm.startPrank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);
        vm.expectRevert(ErrorsLib.NotKeyringWhitelisted.selector);
        vault.deposit(INITIAL_DEPOSIT, nonWhitelistedUser);
    }

    function test_whitelistedUserCanMint() public {
        loanToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);
        vm.startPrank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);
        vault.mint(INITIAL_DEPOSIT, whitelistedUser);
        assertEq(vault.balanceOf(whitelistedUser), INITIAL_DEPOSIT);
    }

    function test_nonWhitelistedUserCannotMint() public {
        loanToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);
        vm.startPrank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);
        vm.expectRevert(ErrorsLib.NotKeyringWhitelisted.selector);
        vault.mint(INITIAL_DEPOSIT, nonWhitelistedUser);
    }

    function test_whitelistedUserCanWithdraw() public {
        // First deposit some tokens
        loanToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);
        vm.startPrank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);
        vault.deposit(INITIAL_DEPOSIT, whitelistedUser);
        vm.stopPrank();

        // Now test withdrawal
        vm.startPrank(whitelistedUser);
        vault.withdraw(INITIAL_DEPOSIT, whitelistedUser, whitelistedUser);
        assertEq(loanToken.balanceOf(whitelistedUser), INITIAL_DEPOSIT);
    }

    function test_nonWhitelistedUserCannotWithdraw() public {
        // First deposit some tokens
        loanToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);
        vm.startPrank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);
        vault.deposit(INITIAL_DEPOSIT, whitelistedUser);
        vm.stopPrank();

        // Now test withdrawal with non-whitelisted user
        vm.startPrank(whitelistedUser);
        vm.expectRevert(ErrorsLib.NotKeyringWhitelisted.selector);
        vault.withdraw(INITIAL_DEPOSIT, nonWhitelistedUser, nonWhitelistedUser);
    }

    function test_whitelistedUserCanRedeem() public {
        // First deposit some tokens
        loanToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);
        vm.startPrank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);
        vault.deposit(INITIAL_DEPOSIT, whitelistedUser);
        vm.stopPrank();

        // Now test redemption
        vm.startPrank(whitelistedUser);
        vault.redeem(INITIAL_DEPOSIT, whitelistedUser, whitelistedUser);
        assertEq(loanToken.balanceOf(whitelistedUser), INITIAL_DEPOSIT);
    }

    function test_nonWhitelistedUserCannotRedeem() public {
        // First deposit some tokens
        loanToken.setBalance(SUPPLIER, INITIAL_DEPOSIT);
        vm.startPrank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);
        vault.deposit(INITIAL_DEPOSIT, whitelistedUser);
        vm.stopPrank();

        // Now test redemption with non-whitelisted user
        vm.startPrank(whitelistedUser);
        vm.expectRevert(ErrorsLib.NotKeyringWhitelisted.selector);
        vault.redeem(INITIAL_DEPOSIT, nonWhitelistedUser, nonWhitelistedUser);
    }
}
