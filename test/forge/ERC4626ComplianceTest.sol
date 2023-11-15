// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "erc4626-tests/ERC4626.test.sol";

import {IntegrationTest} from "./helpers/IntegrationTest.sol";

contract ERC4626ComplianceTest is IntegrationTest, ERC4626Test {
    function setUp() public override(IntegrationTest, ERC4626Test) {
        super.setUp();

        _underlying_ = address(loanToken);
        _vault_ = address(vault);
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = true;

        _setCap(allMarkets[0], 100e18);
        _sortSupplyQueueIdleLast();
    }
}
