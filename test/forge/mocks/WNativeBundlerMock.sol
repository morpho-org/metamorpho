pragma solidity ^0.8.21;

import "contracts/bundlers/WNativeBundler.sol";
import "contracts/bundlers/ERC20Bundler.sol";

contract WNativeBundlerMock is WNativeBundler, ERC20Bundler {
    constructor(address wNative) WNativeBundler(wNative) {}
}
