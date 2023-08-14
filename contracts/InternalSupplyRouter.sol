// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import {MarketAllocation} from "./libraries/Types.sol";
import {Permit2Lib, ERC20 as ERC20Permit2} from "@permit2/libraries/Permit2Lib.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract InternalSupplyRouter is ERC2771Context {
    using Permit2Lib for ERC20Permit2;
    using SafeTransferLib for ERC20;

    IMorpho internal immutable _MORPHO;

    constructor(address morpho, address forwarder) ERC2771Context(forwarder) {
        _MORPHO = IMorpho(morpho);
    }

    /* INTERNAL */

    function _supplyAll(MarketAllocation[] memory allocations, address onBehalf) internal virtual {
        uint256 nbMarkets = allocations.length;

        for (uint256 i; i < nbMarkets; ++i) {
            MarketAllocation memory allocation = allocations[i];

            _supply(allocation, onBehalf);
        }
    }

    function _withdrawAll(MarketAllocation[] memory allocations, address onBehalf, address receiver) internal virtual {
        uint256 nbMarkets = allocations.length;

        for (uint256 i; i < nbMarkets; ++i) {
            MarketAllocation memory allocation = allocations[i];

            _withdraw(allocation, onBehalf, receiver);
        }
    }

    function _supply(MarketAllocation memory allocation, address onBehalf) internal virtual {
        ERC20Permit2(address(allocation.market.borrowableToken)).transferFrom2(
            _msgSender(), address(this), allocation.assets
        );

        _MORPHO.supply(allocation.market, allocation.assets, 0, onBehalf, hex"");
    }

    function _withdraw(MarketAllocation memory allocation, address onBehalf, address receiver) internal virtual {
        _MORPHO.withdraw(allocation.market, allocation.assets, 0, onBehalf, receiver);
    }
}
