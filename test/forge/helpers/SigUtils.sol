// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";

struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}

bytes32 constant PERMIT_TYPEHASH =
    keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

library SigUtils {
    function toTypedDataHash(bytes32 domainSeparator, Permit memory permit) internal pure returns (bytes32) {
        return ECDSA.toTypedDataHash(
            domainSeparator,
            keccak256(
                abi.encode(PERMIT_TYPEHASH, permit.owner, permit.spender, permit.value, permit.nonce, permit.deadline)
            )
        );
    }
}
