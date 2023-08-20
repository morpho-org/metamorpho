// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./mocks/ChainlinkAggregatorV3Mock.sol";
import "./mocks/ERC20Mock.sol";

import "contracts/oracles/ChainlinkPairOracle.sol";

import {FullMath} from "@uniswap/v3-core/libraries/FullMath.sol";

import "@forge-std/console2.sol";
import "@forge-std/Test.sol";

contract ChainlinkOracleTest is Test {
    ChainlinkAggregatorV3Mock collateralFeed;
    ChainlinkAggregatorV3Mock borrowableFeed;
    ChainlinkPairOracle chainlinkOracle;
    ERC20Mock collateral;
    ERC20Mock borrowable;
    uint256 SCALE;
    uint8 COLLATERAL_DECIMALS = 8;
    uint8 BORROWABLE_DECIMALS = 10;

    function setUp() public {
        collateral = new ERC20Mock("Collateral", "COL", 18);
        borrowable = new ERC20Mock("Borrowable", "BOR", 8);

        collateralFeed = new ChainlinkAggregatorV3Mock();
        borrowableFeed = new ChainlinkAggregatorV3Mock();

        collateralFeed.setDecimals(COLLATERAL_DECIMALS);
        borrowableFeed.setDecimals(BORROWABLE_DECIMALS);

        SCALE = 1e26; // 1e36 * 10 ** (8 - 18);

        chainlinkOracle = new ChainlinkPairOracle(address(collateralFeed), address(borrowableFeed), SCALE);
    }

    function testConfig() public {
        assertEq(address(chainlinkOracle.CHAINLINK_COLLATERAL_FEED()), address(collateralFeed));
        assertEq(address(chainlinkOracle.CHAINLINK_BORROWABLE_FEED()), address(borrowableFeed));
        assertEq(chainlinkOracle.COLLATERAL_SCALE(), 10 ** COLLATERAL_DECIMALS);
        assertEq(chainlinkOracle.BORROWABLE_SCALE(), 10 ** BORROWABLE_DECIMALS);
        assertEq(chainlinkOracle.PRICE_SCALE(), SCALE);
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
        collateralDecimals = bound(collateralDecimals, 6, 18);
        borrowableDecimals = bound(borrowableDecimals, 6, 18);
        collateralFeedDecimals = bound(collateralFeedDecimals, 6, 18);
        borrowableFeedDecimals = bound(borrowableFeedDecimals, 6, 18);
        // Cap prices at $10M.
        collateralPrice = bound(collateralPrice, 1, 10_000_000);
        borrowablePrice = bound(borrowablePrice, 1, 10_000_000);

        // Create tokens.
        collateral = new ERC20Mock("Collateral", "COL", uint8(collateralDecimals));
        borrowable = new ERC20Mock("Borrowable", "BOR", uint8(borrowableDecimals));

        collateralPrice = collateralPrice * 10 ** collateralFeedDecimals;
        borrowablePrice = borrowablePrice * 10 ** borrowableFeedDecimals;

        collateralFeed = new ChainlinkAggregatorV3Mock();
        borrowableFeed = new ChainlinkAggregatorV3Mock();

        collateralFeed.setDecimals(uint8(collateralFeedDecimals));
        borrowableFeed.setDecimals(uint8(borrowableFeedDecimals));

        collateralFeed.setLatestAnswer(int256(collateralPrice));
        borrowableFeed.setLatestAnswer(int256(borrowablePrice));

        uint256 scale = collateralDecimals > borrowableDecimals
            ? 1e36 / 10 ** (collateralDecimals - borrowableDecimals)
            : 1e36 * (borrowableDecimals - collateralDecimals); // 1e36 * 10 ** (borrow decimals - collateral decimals);

        chainlinkOracle = new ChainlinkPairOracle(address(collateralFeed), address(borrowableFeed), scale);

        assertEq(
            chainlinkOracle.price(),
            FullMath.mulDiv(
                collateralPrice * 10 ** borrowableFeedDecimals, scale, borrowablePrice * 10 ** collateralFeedDecimals
            )
        );
    }
}
