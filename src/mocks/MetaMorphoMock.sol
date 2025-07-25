// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.21;

import "../MetaMorpho.sol";

contract MetaMorphoMock is MetaMorpho {
    constructor(
        address owner,
        address morpho,
        uint256 initialTimelock,
        address _asset,
        string memory __name,
        string memory __symbol
    ) MetaMorpho(owner, morpho, initialTimelock, _asset, __name, __symbol) {}

    function mockSetCap(MarketParams memory marketParams, Id id, uint184 supplyCap) external {
        _setCap(marketParams, id, supplyCap);
    }

    function mockSimulateWithdrawMorpho(uint256 assets) external view returns (uint256) {
        return _simulateWithdrawMorpho(assets);
    }

    function mockSetSupplyQueue(Id[] memory ids) external {
        supplyQueue = ids;
    }
}
