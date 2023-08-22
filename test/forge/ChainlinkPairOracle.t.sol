// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./mocks/ChainlinkAggregatorV3Mock.sol";
import "./mocks/ERC20Mock.sol";

import "contracts/oracles/ChainlinkPairOracle.sol";

import {OracleFeed} from "contracts/oracles/libraries/OracleFeed.sol";
import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";

import "@forge-std/console2.sol";
import "@forge-std/Test.sol";

contract ChainlinkOracleTest is Test {
    using FullMath for uint256;

    ChainlinkAggregatorV3Mock collateralFeed;
    ChainlinkAggregatorV3Mock borrowableFeed;
    ChainlinkPairOracle chainlinkOracle;
    ERC20Mock collateral;
    ERC20Mock borrowable;
    uint256 SCALE_FACTOR;
    uint8 COLLATERAL_DECIMALS = 8;
    uint8 BORROWABLE_DECIMALS = 10;

    function setUp() public {
        collateral = new ERC20Mock("Collateral", "COL", 18);
        borrowable = new ERC20Mock("Borrowable", "BOR", 8);

        collateralFeed = new ChainlinkAggregatorV3Mock();
        borrowableFeed = new ChainlinkAggregatorV3Mock();

        collateralFeed.setDecimals(COLLATERAL_DECIMALS);
        borrowableFeed.setDecimals(BORROWABLE_DECIMALS);

        SCALE_FACTOR = 10 ** (36 + COLLATERAL_DECIMALS - BORROWABLE_DECIMALS);

        chainlinkOracle = new ChainlinkPairOracle(SCALE_FACTOR, address(collateralFeed), address(borrowableFeed));
    }

    function testConfig() public {
        (string memory collateralOracleFeed, address collateralChainlinkFeed) = chainlinkOracle.COLLATERAL_FEED();
        (string memory borrowableOracleFeed, address borrowableChainlinkFeed) = chainlinkOracle.BORROWABLE_FEED();

        assertEq(collateralOracleFeed, OracleFeed.CHAINLINK_V3, "collateralOracleFeed");
        assertEq(borrowableOracleFeed, OracleFeed.CHAINLINK_V3, "borrowableOracleFeed");
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

        // Create tokens.
        collateral = new ERC20Mock("Collateral", "COL", uint8(collateralDecimals));
        borrowable = new ERC20Mock("Borrowable", "BOR", uint8(borrowableDecimals));

        collateralPrice *= 10 ** collateralFeedDecimals;
        borrowablePrice *= 10 ** borrowableFeedDecimals;

        collateralFeed = new ChainlinkAggregatorV3Mock();
        borrowableFeed = new ChainlinkAggregatorV3Mock();

        collateralFeed.setDecimals(uint8(collateralFeedDecimals));
        borrowableFeed.setDecimals(uint8(borrowableFeedDecimals));

        collateralFeed.setLatestAnswer(int256(collateralPrice));
        borrowableFeed.setLatestAnswer(int256(borrowablePrice));

        uint256 scale = 10 ** (36 + borrowableDecimals - collateralDecimals);

        chainlinkOracle = new ChainlinkPairOracle(scale, address(collateralFeed), address(borrowableFeed));

        uint256 collateralPriceInBorrowable = collateralPrice.mulDiv(10 ** borrowableFeedDecimals, borrowablePrice);

        assertEq(chainlinkOracle.price(), scale.mulDiv(collateralPriceInBorrowable, 10 ** collateralFeedDecimals));
    }
}
