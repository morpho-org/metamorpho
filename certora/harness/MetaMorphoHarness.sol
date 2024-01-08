// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import "../munged/MetaMorpho.sol";

contract MetaMorphoHarness is MetaMorpho {
    constructor(
        address owner,
        address morpho,
        uint256 initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) MetaMorpho(owner, morpho, initialTimelock, _asset, _name, _symbol) {}

    function maxFee() external view returns (uint256) {
        return ConstantsLib.MAX_FEE;
    }

    function minTimelock() external view returns (uint256) {
        return ConstantsLib.MIN_TIMELOCK;
    }

    function maxTimelock() external view returns (uint256) {
        return ConstantsLib.MAX_TIMELOCK;
    }
}
