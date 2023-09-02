// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.21;

import {IIrm} from "@morpho-blue/interfaces/IIrm.sol";
import {MarketAllocation} from "../interfaces/ISupplyVault.sol";
import {IVaultAllocationStrategy} from "../interfaces/IVaultAllocationStrategy.sol";
import {Id, MarketParams, Market, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import {MathLib} from "@morpho-blue/libraries/MathLib.sol";
import {UtilsLib} from "@morpho-blue/libraries/UtilsLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";
import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";
import {IMorphoMarketStruct} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

contract HighestAPRSupplyStrategy is IVaultAllocationStrategy {
    using MathLib for uint128;
    using MathLib for uint256;
    using UtilsLib for uint256;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;

    IMorpho public immutable MORPHO;

    constructor(address morpho) {
        MORPHO = IMorpho(morpho);
    }

    function allocate(address, address, uint256 assets, MarketParams[] calldata allMarketParams)
        external
        view
        returns (MarketAllocation[] memory withdrawn, MarketAllocation[] memory supplied)
    {
        uint256 topApr;
        MarketParams memory topMarketParams;

        uint256 nbMarkets = allMarketParams.length;
        for (uint256 i; i < nbMarkets; ++i) {
            MarketParams memory marketParams = allMarketParams[i];
            Id id = marketParams.id();

            Market memory market = IMorphoMarketStruct(address(MORPHO)).market(id);
            uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);

            uint256 elapsed = block.timestamp - market.lastUpdate;

            if (elapsed != 0 && market.totalBorrowAssets != 0) {
                uint256 interest = market.totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));
                market.totalBorrowAssets += interest.toUint128();
                market.totalSupplyAssets += interest.toUint128();

                if (market.fee != 0) {
                    uint256 feeAmount = interest.wMulDown(market.fee);
                    // The fee amount is subtracted from the total supply in this calculation to compensate for the fact
                    // that total supply is already updated.
                    uint256 feeShares =
                        feeAmount.toSharesDown(market.totalSupplyAssets - feeAmount, market.totalSupplyShares);
                    market.totalSupplyShares += feeShares.toUint128();
                }
            }

            uint256 hypotheticalUtilization = market.totalBorrowAssets.wMulDown(market.totalSupplyAssets + assets);
            uint256 hypotheticalApr = borrowRate.wMulDown(hypotheticalUtilization);

            if (topApr < hypotheticalApr) {
                topApr = hypotheticalApr;
                topMarketParams = marketParams;
            }
        }

        withdrawn = new MarketAllocation[](0);
        supplied = new MarketAllocation[](1);
        supplied[0] = MarketAllocation({marketParams: topMarketParams, assets: assets});
    }
}
