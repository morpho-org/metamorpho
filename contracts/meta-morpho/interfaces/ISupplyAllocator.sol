// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface ISupplyAllocator {
    function allocateSupply(address asset, uint256 amount, bytes memory collateralization)
        external
        view
        returns (bytes memory allocation);

    function allocateWithdraw(address asset, uint256 amount, bytes memory collateralization)
        external
        view
        returns (bytes memory allocation);
}
