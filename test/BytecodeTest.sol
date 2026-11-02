// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";

import "../src/MetaMorphoFactory.sol";

contract BytecodeTest is Test {
    /// @dev The file holds the creation code of MetaMorphoFactory v1.0, deployed on Ethereum at
    /// 0xA9c3D3a366466Fa809d1Ae982Fb2c46E5fC41101 in transaction
    /// 0x05504ab1f9d86603298083de89f7a07e3be7633e354c78a626a11f06ad71efca, without the constructor argument.
    function testFactoryCreationCodeMatchesEthereumDeployment() public view {
        bytes memory deployed = vm.parseBytes(vm.readLine("test/helpers/MetaMorphoFactoryCreationCode.hex"));
        assertEq(maskIpfsHashes(deployed), maskIpfsHashes(type(MetaMorphoFactory).creationCode));
    }

    /// @dev Zeroes the IPFS hashes of the metadata.
    function maskIpfsHashes(bytes memory code) internal pure returns (bytes memory) {
        for (uint256 i; i + 42 <= code.length; i++) {
            bytes8 prefix;
            assembly {
                prefix := mload(add(add(code, 32), i))
            }
            // CBOR prefix: map of 2 entries, "ipfs", 34 bytes.
            if (prefix == 0xa264697066735822) {
                for (uint256 j = i + 8; j < i + 42; j++) {
                    code[j] = 0;
                }
            }
        }
        return code;
    }
}
