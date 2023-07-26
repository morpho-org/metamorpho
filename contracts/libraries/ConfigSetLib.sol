// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Id, Market} from "@morpho-blue/interfaces/IBlue.sol";

import {MarketLib} from "@morpho-blue/libraries/MarketLib.sol";

struct MarketConfigData {
    uint256 cap;
}

struct MarketConfig {
    uint256 rank;
    MarketConfigData config;
}

struct ConfigSet {
    Market[] markets;
    mapping(Id marketId => MarketConfig) market;
}

library ConfigSetLib {
    using MarketLib for Market;

    /**
     * @dev Add a value to a set. O(1).
     */
    function add(ConfigSet storage set, Market memory key, MarketConfigData calldata config) internal returns (bool) {
        MarketConfig storage market = getMarket(set, key);

        market.config = config;

        if (contains(set, key)) return false;

        set.markets.push(key);
        // The value is stored at length-1, but we add 1 to all indexes
        // and use 0 as a sentinel value
        market.rank = set.markets.length;

        return true;
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(ConfigSet storage set, Market memory key) internal returns (bool) {
        Id id = key.id();

        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 rank = set.market[id].rank;

        if (rank == 0) return false;

        // Equivalent to contains(set, value)
        // To delete an element from the markets array in O(1), we swap the element to delete with the last one in
        // the array, and then remove the last element (sometimes called as 'swap and pop').
        // This modifies the order of the array, as noted in {at}.

        uint256 toDeleteIndex;
        uint256 lastIndex;

        unchecked {
            toDeleteIndex = rank - 1;
            lastIndex = set.markets.length - 1;
        }

        if (lastIndex != toDeleteIndex) {
            Market memory lastValue = set.markets[lastIndex];

            // Move the last value to the index where the value to delete is
            set.markets[toDeleteIndex] = lastValue;
            // Update the index for the moved value
            set.market[lastValue.id()].rank = rank; // Replace lastValue's index to rank
        }

        // Delete the slot where the moved value was stored
        set.markets.pop();

        // Delete the index for the deleted slot
        delete set.market[id];

        return true;
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(ConfigSet storage set, Market memory key) internal view returns (bool) {
        return set.market[key.id()].rank != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(ConfigSet storage set) internal view returns (uint256) {
        return set.markets.length;
    }

    /**
     * @dev Returns the market config stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(ConfigSet storage set, uint256 index) internal view returns (Market storage) {
        return set.markets[index];
    }

    /**
     * @dev Returns the market config stored for a given market. O(1).
     */
    function getMarket(ConfigSet storage set, Market memory key) internal view returns (MarketConfig storage) {
        return set.market[key.id()];
    }
}
