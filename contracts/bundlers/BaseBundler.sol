// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.21;

import {IMulticall} from "./interfaces/IMulticall.sol";

import {Errors} from "./libraries/Errors.sol";

import {BaseSelfMulticall} from "../BaseSelfMulticall.sol";
import {BaseCallbackReceiver} from "../BaseCallbackReceiver.sol";

/// @title BaseBundler
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
abstract contract BaseBundler is BaseSelfMulticall, BaseCallbackReceiver {
    /* EXTERNAL */

    function multicall(uint256 deadline, bytes[] calldata data)
        external
        payable
        lockInitiator
        returns (bytes[] memory)
    {
        require(block.timestamp <= deadline, Errors.DEADLINE_EXPIRED);

        return _multicall(data);
    }

    function callBundler(address bundler, bytes[] calldata data) external {
        require(bundler != address(0), Errors.ZERO_ADDRESS);

        IMulticall(bundler).multicall(block.timestamp, data);
    }
}
