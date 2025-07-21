// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";
import {MetaMorpho, SafeERC20} from "../../../src/MetaMorpho.sol";

contract InternalTest is BaseTest, MetaMorpho {
    using SafeERC20 for IERC20;

    address constant tempOwner = address(100);
    address constant tempMorpho = address(101);

    constructor()
        MetaMorpho(
            tempOwner,
            tempMorpho,
            ConstantsLib.MIN_TIMELOCK,
            address(new ERC20Mock("tT", "tempToken")),
            "MetaMorpho Vault",
            "MM"
        )
    {
        DECIMALS_OFFSET = 0;
        MORPHO = morpho;
        IERC20(asset()).forceApprove(address(morpho), type(uint256).max);
    }

    function asset() public view override returns (address) {
        return address(loanToken);
    }

    function setUp() public virtual override {
        super.setUp();

        vm.prank(tempOwner);
        this.transferOwnership(OWNER);

        vm.startPrank(OWNER);
        this.acceptOwnership();
        this.setCurator(CURATOR);
        this.setIsAllocator(ALLOCATOR, true);
        vm.stopPrank();

        vm.startPrank(SUPPLIER);
        loanToken.approve(address(this), type(uint256).max);
        collateralToken.approve(address(this), type(uint256).max);
        vm.stopPrank();
    }
}
