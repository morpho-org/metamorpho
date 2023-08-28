// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {ChainlinkAggregatorV3Mock} from "test/forge/mocks/ChainlinkAggregatorV3Mock.sol";

import "contracts/oracles/ChainlinkPairOracle.sol";

import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";

import "@forge-std/console2.sol";
import "@forge-std/Test.sol";

contract ChainlinkOracleTest is Test {
    using FullMath for uint256;

    ChainlinkAggregatorV3Mock collateralFeed;
    ChainlinkAggregatorV3Mock borrowableFeed;
    ChainlinkPairOracle chainlinkOracle;

    uint256 SCALE_FACTOR;
    uint8 COLLATERAL_DECIMALS = 8;
    uint8 BORROWABLE_DECIMALS = 10;
    uint256 BOUND_OFFSET_FACTOR = 0;

    function setUp() public {
        collateralFeed = new ChainlinkAggregatorV3Mock();
        borrowableFeed = new ChainlinkAggregatorV3Mock();

        collateralFeed.setDecimals(COLLATERAL_DECIMALS);
        borrowableFeed.setDecimals(BORROWABLE_DECIMALS);

        SCALE_FACTOR = 10 ** (36 + BORROWABLE_DECIMALS - COLLATERAL_DECIMALS);

        chainlinkOracle =
        new ChainlinkPairOracle(SCALE_FACTOR, address(collateralFeed), BOUND_OFFSET_FACTOR, address(borrowableFeed), BOUND_OFFSET_FACTOR);
    }

    function testConfig() public {
        address collateralChainlinkFeed = chainlinkOracle.COLLATERAL_FEED();
        address borrowableChainlinkFeed = chainlinkOracle.BORROWABLE_FEED();

        assertEq(collateralChainlinkFeed, address(collateralFeed), "collateralChainlinkFeed");
        assertEq(borrowableChainlinkFeed, address(borrowableFeed), "borrowableChainlinkFeed");
        assertEq(chainlinkOracle.COLLATERAL_SCALE(), 10 ** COLLATERAL_DECIMALS);
        assertEq(chainlinkOracle.BORROWABLE_SCALE(), 10 ** BORROWABLE_DECIMALS);
        assertEq(chainlinkOracle.SCALE_FACTOR(), SCALE_FACTOR);
    }

    function testNegativePrice(int256 price) public {
        vm.assume(price < 0);

        collateralFeed.setLatestAnswer(int256(price));

        vm.expectRevert();
        chainlinkOracle.price();
    }

    function testPrice(
        uint256 collateralDecimals,
        uint256 borrowableDecimals,
        uint256 collateralPrice,
        uint256 borrowablePrice,
        uint256 collateralFeedDecimals,
        uint256 borrowableFeedDecimals
    ) public {
        borrowableDecimals = bound(borrowableDecimals, 0, 27);
        collateralDecimals = bound(collateralDecimals, 0, 36 + borrowableDecimals);
        collateralFeedDecimals = bound(collateralFeedDecimals, 0, 27);
        borrowableFeedDecimals = bound(borrowableFeedDecimals, 0, 27);
        // Cap prices at $10M.
        collateralPrice = bound(collateralPrice, 1, 10_000_000);
        borrowablePrice = bound(borrowablePrice, 1, 10_000_000);

        collateralPrice *= 10 ** collateralFeedDecimals;
        borrowablePrice *= 10 ** borrowableFeedDecimals;

        collateralFeed = new ChainlinkAggregatorV3Mock();
        borrowableFeed = new ChainlinkAggregatorV3Mock();

        collateralFeed.setDecimals(uint8(collateralFeedDecimals));
        borrowableFeed.setDecimals(uint8(borrowableFeedDecimals));

        collateralFeed.setLatestAnswer(int256(collateralPrice));
        borrowableFeed.setLatestAnswer(int256(borrowablePrice));

        uint256 scale = 10 ** (36 + borrowableDecimals - collateralDecimals);

        chainlinkOracle =
        new ChainlinkPairOracle(scale, address(collateralFeed), BOUND_OFFSET_FACTOR, address(borrowableFeed), BOUND_OFFSET_FACTOR);

        uint256 invBorrowablePrice = scale.mulDiv(10 ** borrowableFeedDecimals, borrowablePrice);

        assertEq(chainlinkOracle.price(), collateralPrice.mulDiv(invBorrowablePrice, 10 ** collateralFeedDecimals));
    }
}
