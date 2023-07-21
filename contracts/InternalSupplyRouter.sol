// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import {MarketAllocation} from "contracts/libraries/Types.sol";
import {MarketKey} from "@morpho-blue/libraries/Types.sol";
import {MarketKeyLib} from "@morpho-blue/libraries/MarketKeyLib.sol";
import {Permit2Lib, ERC20} from "@permit2/libraries/Permit2Lib.sol";

import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract InternalSupplyRouter is ERC2771Context {
    using MarketKeyLib for MarketKey;
    using Permit2Lib for ERC20;

    IMorpho internal immutable _MORPHO;

    constructor(address morpho, address forwarder) ERC2771Context(forwarder) {
        _MORPHO = IMorpho(morpho);
    }

    /* INTERNAL */

    function _depositAll(MarketAllocation[] memory allocations, address onBehalf) internal virtual {
        uint256 nbMarkets = allocations.length;

        for (uint256 i; i < nbMarkets; ++i) {
            MarketAllocation memory allocation = allocations[i];

            _deposit(allocation, onBehalf);
        }
    }

    function _withdrawAll(MarketAllocation[] memory allocations, address onBehalf, address receiver) internal virtual {
        uint256 nbMarkets = allocations.length;

        for (uint256 i; i < nbMarkets; ++i) {
            MarketAllocation memory allocation = allocations[i];

            _withdraw(allocation, onBehalf, receiver);
        }
    }

    function _deposit(MarketAllocation memory allocation, address onBehalf) internal virtual {
        ERC20(allocation.marketKey.asset).transferFrom2(_msgSender(), address(this), allocation.assets);

        _MORPHO.deposit(allocation.marketKey, allocation.assets, onBehalf);
    }

    function _withdraw(MarketAllocation memory allocation, address onBehalf, address receiver) internal virtual {
        _MORPHO.withdraw(allocation.marketKey, allocation.assets, onBehalf, receiver);
    }
}
