// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {
    Math,
    MetaMorphoV1_1,
    Id,
    ConstantsLib,
    PendingUint192,
    PendingAddress,
    MarketConfig
} from "../../../munged/v1.1/MetaMorphoV1_1.sol";
import {IMorpho} from "../../../lib/morpho-blue/src/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from "../../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

contract MetaMorphoHarness is MetaMorphoV1_1 {
    using MorphoBalancesLib for IMorpho;

    constructor(
        address owner,
        address morpho,
        uint256 initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) MetaMorphoV1_1(owner, morpho, initialTimelock, _asset, _name, _symbol) {}

    function pendingTimelock_() external view returns (PendingUint192 memory) {
        return pendingTimelock;
    }

    function pendingGuardian_() external view returns (PendingAddress memory) {
        return pendingGuardian;
    }

    function config_(Id id) external view returns (MarketConfig memory) {
        return config[id];
    }

    function pendingCap_(Id id) external view returns (PendingUint192 memory) {
        return pendingCap[id];
    }

    function minTimelock() external pure returns (uint256) {
        return ConstantsLib.POST_INITIALIZATION_MIN_TIMELOCK;
    }

    function maxTimelock() external pure returns (uint256) {
        return ConstantsLib.MAX_TIMELOCK;
    }

    function maxQueueLength() external pure returns (uint256) {
        return ConstantsLib.MAX_QUEUE_LENGTH;
    }

    function maxFee() external pure returns (uint256) {
        return ConstantsLib.MAX_FEE;
    }

    function nextGuardianUpdateTime() external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) {
            nextTime = Math.min(nextTime, pendingTimelock.validAt + pendingTimelock.value);
        }

        uint256 validAt = pendingGuardian.validAt;
        if (validAt != 0) nextTime = Math.min(nextTime, validAt);
    }

    function nextCapIncreaseTime(Id id) external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) {
            nextTime = Math.min(nextTime, pendingTimelock.validAt + pendingTimelock.value);
        }

        uint256 validAt = pendingCap[id].validAt;
        if (validAt != 0) nextTime = Math.min(nextTime, validAt);
    }

    function nextTimelockDecreaseTime() external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) nextTime = Math.min(nextTime, pendingTimelock.validAt);
    }

    function nextRemovableTime(Id id) external view returns (uint256 nextTime) {
        nextTime = block.timestamp + timelock;

        if (pendingTimelock.validAt != 0) {
            nextTime = Math.min(nextTime, pendingTimelock.validAt + pendingTimelock.value);
        }

        uint256 removableAt = config[id].removableAt;
        if (removableAt != 0) nextTime = Math.min(nextTime, removableAt);
    }

    function realTotalAssets() public view returns (uint256) {
        uint256 _realTotalAssets;
        for (uint256 i; i < withdrawQueue.length; ++i) {
            _realTotalAssets += MORPHO.expectedSupplyAssets(_marketParams(withdrawQueue[i]), address(this));
        }
        return _realTotalAssets;
    }

    function newLostAssets() external view returns (uint256) {
        uint256 _realTotalAssets = realTotalAssets();

        uint256 _newLostAssets;
        if (_realTotalAssets < lastTotalAssets - lostAssets) _newLostAssets = lastTotalAssets - _realTotalAssets;
        else _newLostAssets = lostAssets;

        return _newLostAssets;
    }
}
