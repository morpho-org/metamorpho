// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import {MarketAllocation} from "contracts/libraries/Types.sol";
import {Permit2Lib, ERC20} from "@permit2/libraries/Permit2Lib.sol";

import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract InternalSupplyRouter is ERC2771Context {
    IMorpho internal immutable _MORPHO;

    constructor(address morpho, address forwarder) ERC2771Context(forwarder) {
        _MORPHO = IMorpho(morpho);
    }
}
