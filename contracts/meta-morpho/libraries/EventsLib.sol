// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library EventsLib {
    event SetRiskManager(address indexed riskManager, bool isRiskManager);

    event SetAllocator(address indexed allocator, bool isAllocator);

    event SetSupplyStrategy(address indexed supplyStrategy);

    event SetWithdrawStrategy(address indexed withdrawStrategy);
}
