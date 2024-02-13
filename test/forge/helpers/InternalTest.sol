// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";
import {MetaMorpho} from "../../../src/MetaMorpho.sol";

contract InternalTest is BaseTest, MetaMorpho {
    constructor()
        MetaMorpho(OWNER, address(morpho), ConstantsLib.MIN_TIMELOCK, address(loanToken), "MetaMorpho Vault", "MM")
    {}

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(OWNER);
        this.setCurator(CURATOR);
        this.setIsAllocator(ALLOCATOR, true);
        vm.stopPrank();

        vm.startPrank(SUPPLIER);
        loanToken.approve(address(this), type(uint256).max);
        collateralToken.approve(address(this), type(uint256).max);
        vm.stopPrank();
    }
}
