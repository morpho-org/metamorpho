// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

import "../../../src/v1.1/MetaMorphoV1_1.sol";

contract MetaMorphoMock is MetaMorphoV1_1 {
    constructor(
        address owner,
        address morpho,
        uint256 initialTimelock,
        address _asset,
        string memory __name,
        string memory __symbol
    ) MetaMorphoV1_1(owner, morpho, initialTimelock, _asset, __name, __symbol) {}

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
