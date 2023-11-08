// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/SigUtils.sol";

import {ERC20Permit} from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import "./helpers/IntegrationTest.sol";

contract PermitTest is IntegrationTest {
    uint256 internal constant OWNER_PK = 0xA11CE;
    uint256 internal constant SPENDER_PK = 0xB0B;
    uint256 internal constant DEADLINE = 1 days;

    address internal owner;
    address internal spender;

    function setUp() public override {
        super.setUp();

        owner = vm.addr(OWNER_PK);
        spender = vm.addr(SPENDER_PK);

        deal(address(vault), owner, 1e18);
    }

    function testPermit() public {
        Permit memory permit = Permit({owner: owner, spender: spender, value: 1e18, nonce: 0, deadline: DEADLINE});

        bytes32 digest = SigUtils.toTypedDataHash(vault.DOMAIN_SEPARATOR(), permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        assertEq(vault.allowance(owner, spender), 1e18);
        assertEq(vault.nonces(owner), 1);
    }

    function testRevertExpiredPermit() public {
        Permit memory permit =
            Permit({owner: owner, spender: spender, value: 1e18, nonce: vault.nonces(owner), deadline: DEADLINE});

        bytes32 digest = SigUtils.toTypedDataHash(vault.DOMAIN_SEPARATOR(), permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vm.warp(DEADLINE + 1 seconds); // fast forward one second past the deadline

        vm.expectRevert(abi.encodeWithSelector(ERC20Permit.ERC2612ExpiredSignature.selector, DEADLINE));
        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertInvalidSigner() public {
        Permit memory permit =
            Permit({owner: owner, spender: spender, value: 1e18, nonce: vault.nonces(owner), deadline: DEADLINE});

        bytes32 digest = SigUtils.toTypedDataHash(vault.DOMAIN_SEPARATOR(), permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SPENDER_PK, digest); // spender signs owner's approval

        vm.expectRevert(abi.encodeWithSelector(ERC20Permit.ERC2612InvalidSigner.selector, permit.spender, permit.owner));
        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertInvalidNonce() public {
        Permit memory permit = Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 1, // owner nonce stored on-chain is 0
            deadline: DEADLINE
        });

        bytes32 digest = SigUtils.toTypedDataHash(vault.DOMAIN_SEPARATOR(), permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vm.expectRevert();
        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertSignatureReplay() public {
        Permit memory permit = Permit({owner: owner, spender: spender, value: 1e18, nonce: 0, deadline: DEADLINE});

        bytes32 digest = SigUtils.toTypedDataHash(vault.DOMAIN_SEPARATOR(), permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.expectRevert();
        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testTransferFromLimitedPermit() public {
        Permit memory permit = Permit({owner: owner, spender: spender, value: 1e18, nonce: 0, deadline: DEADLINE});

        bytes32 digest = SigUtils.toTypedDataHash(vault.DOMAIN_SEPARATOR(), permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        vault.transferFrom(owner, spender, 1e18);

        assertEq(vault.balanceOf(owner), 0);
        assertEq(vault.balanceOf(spender), 1e18);
        assertEq(vault.allowance(owner, spender), 0);
    }

    function testTransferFromMaxPermit() public {
        Permit memory permit =
            Permit({owner: owner, spender: spender, value: type(uint256).max, nonce: 0, deadline: DEADLINE});

        bytes32 digest = SigUtils.toTypedDataHash(vault.DOMAIN_SEPARATOR(), permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        vault.transferFrom(owner, spender, 1e18);

        assertEq(vault.balanceOf(owner), 0);
        assertEq(vault.balanceOf(spender), 1e18);
        assertEq(vault.allowance(owner, spender), type(uint256).max);
    }

    function testFailInvalidAllowance() public {
        Permit memory permit = Permit({
            owner: owner,
            spender: spender,
            value: 5e17, // approve only 0.5 tokens
            nonce: 0,
            deadline: DEADLINE
        });

        bytes32 digest = SigUtils.toTypedDataHash(vault.DOMAIN_SEPARATOR(), permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        vault.transferFrom(owner, spender, 1e18); // attempt to transfer 1 vault
    }

    function testFailInvalidBalance() public {
        Permit memory permit = Permit({
            owner: owner,
            spender: spender,
            value: 2e18, // approve 2 tokens
            nonce: 0,
            deadline: DEADLINE
        });

        bytes32 digest = SigUtils.toTypedDataHash(vault.DOMAIN_SEPARATOR(), permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        vault.transferFrom(owner, spender, 2e18); // attempt to transfer 2 tokens (owner only owns 1)
    }
}
