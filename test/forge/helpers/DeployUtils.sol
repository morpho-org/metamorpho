pragma solidity ^0.8.0;

import "@forge-std/Test.sol";

contract DeployUtils is Test {
    using stdJson for string;

    function _deploy(string memory artifactPath, bytes memory constructorArgs) internal returns (address deployed) {
        deployed = deployCode(artifactPath, constructorArgs);

        require(deployed != address(0), string.concat("could not deploy `", artifactPath, "`"));
    }
}
