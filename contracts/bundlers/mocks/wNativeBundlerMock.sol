pragma solidity ^0.8.21;

import "../WNativeBundler.sol";
import "../ERC20Bundler.sol";

contract WNativeBundlerMock is WNativeBundler, ERC20Bundler {
    constructor(address wNative) WNativeBundler(wNative) {}
}
