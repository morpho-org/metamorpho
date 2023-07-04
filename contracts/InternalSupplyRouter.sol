// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import {MarketAllocation} from "contracts/libraries/Types.sol";
import {MarketKey, MarketKeyLib} from "@morpho-blue/libraries/MarketKeyLib.sol";
import {Permit2Lib, ERC20} from "@permit2/libraries/Permit2Lib.sol";

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

contract InternalSupplyRouter is Context {
    using MarketKeyLib for MarketKey;
    using Permit2Lib for ERC20;

    IMorpho internal immutable _MORPHO;

    constructor(address morpho) {
        _MORPHO = IMorpho(morpho);
    }

    /* INTERNAL */

    function _supplyAll(MarketAllocation[] calldata allocations, address onBehalf) internal virtual {
        uint256 nbMarkets = allocations.length;

        for (uint256 i; i < nbMarkets; ++i) {
            MarketAllocation calldata allocation = allocations[i];

            _supply(allocation, onBehalf);
        }
    }

    function _withdrawAll(MarketAllocation[] calldata allocations, address onBehalf, address receiver)
        internal
        virtual
    {
        uint256 nbMarkets = allocations.length;

        for (uint256 i; i < nbMarkets; ++i) {
            MarketAllocation calldata allocation = allocations[i];

            _withdraw(allocation, onBehalf, receiver);
        }
    }

    function _supply(MarketAllocation calldata allocation, address onBehalf) internal virtual {
        ERC20(allocation.marketKey.asset).transferFrom2(_msgSender(), address(this), allocation.assets);

        _MORPHO.deposit(allocation.marketKey, allocation.trancheId, allocation.assets, onBehalf);
    }

    function _withdraw(MarketAllocation calldata allocation, address onBehalf, address receiver) internal virtual {
        _MORPHO.withdraw(allocation.marketKey, allocation.trancheId, allocation.assets, onBehalf, receiver);
    }
}
