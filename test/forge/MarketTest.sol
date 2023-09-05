// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract MarketTest is BaseTest {
    using MarketParamsLib for MarketParams;

    function testSetConfig(MarketParams memory marketParamsFuzz, VaultMarketConfig calldata marketConfigFuzz) public {
        marketParamsFuzz.borrowableToken = address(borrowableToken);

        vm.prank(RISK_MANAGER);
        vault.setConfig(marketParamsFuzz, marketConfigFuzz);

        VaultMarketConfig memory config = vault.config(marketParamsFuzz.id());

        assertEq(config.cap, marketConfigFuzz.cap);
    }
}
