// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Market, MarketConfig} from "./Types.sol";
import {TrancheId} from "@morpho-blue/libraries/Types.sol";

library MarketLib {
    function setConfig(Market storage market, MarketConfig calldata config) internal {
        deleteTranches(market);

        market.config = config;

        uint256 _nbTranches = nbTranches(market);
        for (uint256 i; i < _nbTranches;) {
            TrancheId trancheId = trancheAt(market, i);

            market.trancheRank[trancheId] = ++i;
        }
    }

    function deleteTranches(Market storage market) internal {
        uint256 _nbTranches = nbTranches(market);

        for (uint256 i; i < _nbTranches; ++i) {
            TrancheId trancheId = trancheAt(market, i);

            delete market.trancheRank[trancheId];
        }
    }

    /**
     * @dev Add a tranche to a market. O(1).
     *
     * Returns true if the tranche was added to the market, that is if it was not
     * already present.
     */
    function addTranche(Market storage market, TrancheId trancheId) internal returns (bool) {
        if (hasTranche(market, trancheId)) return false;

        market.config.trancheIds.push(trancheId);
        // The tranche is stored at length-1, but we add 1 to all indexes
        // and use 0 as a sentinel value
        market.trancheRank[trancheId] = market.config.trancheIds.length;

        return true;
    }

    /**
     * @dev Removes a tranche from a market. O(1).
     *
     * Returns true if the tranche was removed from the market, that is if it was
     * present.
     */
    function removeTranche(Market storage market, TrancheId trancheId) internal returns (bool) {
        // We read and store the tranche's index to prevent multiple reads from the same storage slot
        uint256 trancheRank = market.trancheRank[trancheId];

        if (trancheRank == 0) return false;

        // Equivalent to contains(market, tranche)
        // To delete an element from the config.trancheIds array in O(1), we swap the element to delete with the last one in
        // the array, and then remove the last element (sometimes called as 'swap and pop').
        // This modifies the order of the array, as noted in {at}.

        uint256 toDeleteIndex = trancheRank - 1;
        uint256 lastIndex = market.config.trancheIds.length - 1;

        if (lastIndex != toDeleteIndex) {
            TrancheId lastValue = market.config.trancheIds[lastIndex];

            // Move the last tranche to the index where the tranche to delete is
            market.config.trancheIds[toDeleteIndex] = lastValue;
            // Update the index for the moved tranche
            market.trancheRank[lastValue] = trancheRank; // Replace lastValue's index to trancheRank
        }

        // Delete the slot where the moved tranche was stored
        market.config.trancheIds.pop();

        // Delete the index for the deleted slot
        delete market.trancheRank[trancheId];

        return true;
    }

    /**
     * @dev Returns true if the tranche is in the market. O(1).
     */
    function hasTranche(Market storage market, TrancheId trancheId) internal view returns (bool) {
        return market.trancheRank[trancheId] != 0;
    }

    /**
     * @dev Returns the number of tranches on the market. O(1).
     */
    function nbTranches(Market storage market) internal view returns (uint256) {
        return market.config.trancheIds.length;
    }

    /**
     * @dev Returns the tranche stored at position `index` in the market. O(1).
     *
     * Note that there are no guarantees on the ordering of tranches inside the
     * array, and it may change when more tranches are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function trancheAt(Market storage market, uint256 index) internal view returns (TrancheId) {
        return market.config.trancheIds[index];
    }
}
