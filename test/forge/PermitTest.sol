// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/SigUtils.sol";
import "./helpers/BaseTest.sol";

contract PermitTest is BaseTest {
    SigUtils internal sigUtils;

    uint256 internal constant OWNER_PK = 0xA11CE;
    uint256 internal constant SPENDER_PK = 0xB0B;

    address internal owner;
    address internal spender;

    function setUp() public override {
        super.setUp();

        sigUtils = new SigUtils(vault.DOMAIN_SEPARATOR());

        owner = vm.addr(OWNER_PK);
        spender = vm.addr(SPENDER_PK);

        deal(address(vault), owner, 1e18);
    }

    function testPermit() public {
        Permit memory permit = Permit({owner: owner, spender: spender, value: 1e18, nonce: 0, deadline: 1 days});

        bytes32 digest = sigUtils.toTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        assertEq(vault.allowance(owner, spender), 1e18);
        assertEq(vault.nonces(owner), 1);
    }

    function testRevertExpiredPermit() public {
        Permit memory permit =
            Permit({owner: owner, spender: spender, value: 1e18, nonce: vault.nonces(owner), deadline: 1 days});

        bytes32 digest = sigUtils.toTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vm.warp(1 days + 1 seconds); // fast forward one second past the deadline

        vm.expectRevert("ERC20Permit: expired deadline");
        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertInvalidSigner() public {
        Permit memory permit =
            Permit({owner: owner, spender: spender, value: 1e18, nonce: vault.nonces(owner), deadline: 1 days});

        bytes32 digest = sigUtils.toTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SPENDER_PK, digest); // spender signs owner's approval

        vm.expectRevert("ERC20Permit: invalid signature");
        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertInvalidNonce() public {
        Permit memory permit = Permit({
            owner: owner,
            spender: spender,
            value: 1e18,
            nonce: 1, // owner nonce stored on-chain is 0
            deadline: 1 days
        });

        bytes32 digest = sigUtils.toTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vm.expectRevert("ERC20Permit: invalid signature");
        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertSignatureReplay() public {
        Permit memory permit = Permit({owner: owner, spender: spender, value: 1e18, nonce: 0, deadline: 1 days});

        bytes32 digest = sigUtils.toTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.expectRevert("ERC20Permit: invalid signature");
        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testTransferFromLimitedPermit() public {
        Permit memory permit = Permit({owner: owner, spender: spender, value: 1e18, nonce: 0, deadline: 1 days});

        bytes32 digest = sigUtils.toTypedDataHash(permit);
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
            Permit({owner: owner, spender: spender, value: type(uint256).max, nonce: 0, deadline: 1 days});

        bytes32 digest = sigUtils.toTypedDataHash(permit);
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
            deadline: 1 days
        });

        bytes32 digest = sigUtils.toTypedDataHash(permit);
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
            deadline: 1 days
        });

        bytes32 digest = sigUtils.toTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PK, digest);

        vault.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        vault.transferFrom(owner, spender, 2e18); // attempt to transfer 2 tokens (owner only owns 1)
    }
}
