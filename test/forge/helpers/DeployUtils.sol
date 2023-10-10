pragma solidity ^0.8.0;

import "@forge-std/Test.sol";

contract DeployUtils is Test {
    using stdJson for string;

    function _deploy(string memory artifactPath, bytes memory constructorArgs) public returns (address deployed) {
        string memory artifact = vm.readFile(artifactPath);
        bytes memory bytecode = bytes.concat(artifact.readBytes("$.bytecode.object"), constructorArgs);

        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        require(deployed != address(0), string.concat("could not deploy `", artifactPath, "`"));
    }
}
