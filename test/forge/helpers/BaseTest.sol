// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../../../lib/morpho-blue/src/interfaces/IMorpho.sol";

import {WAD, MathLib} from "../../../lib/morpho-blue/src/libraries/MathLib.sol";
import {Math} from "../../../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import {MarketParamsLib} from "../../../lib/morpho-blue/src/libraries/MarketParamsLib.sol";
import {MorphoLib} from "../../../lib/morpho-blue/src/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "../../../lib/morpho-blue/src/libraries/periphery/MorphoBalancesLib.sol";

import "../../../src/interfaces/IMetaMorpho.sol";

import "../../../src/libraries/ConstantsLib.sol";
import {ErrorsLib} from "../../../src/libraries/ErrorsLib.sol";
import {EventsLib} from "../../../src/libraries/EventsLib.sol";
import {ORACLE_PRICE_SCALE} from "../../../lib/morpho-blue/src/libraries/ConstantsLib.sol";

import {IrmMock} from "../../../src/mocks/IrmMock.sol";
import {ERC20Mock} from "../../../src/mocks/ERC20Mock.sol";
import {OracleMock} from "../../../src/mocks/OracleMock.sol";

import {Ownable} from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {IERC20, ERC20} from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/forge-std/src/console2.sol";

uint256 constant BLOCK_TIME = 1;
uint256 constant MIN_TEST_ASSETS = 1e8;
uint256 constant MAX_TEST_ASSETS = 1e28;
uint184 constant CAP = type(uint128).max;
uint256 constant NB_MARKETS = ConstantsLib.MAX_QUEUE_LENGTH + 1;

contract BaseTest is Test {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    address internal OWNER = makeAddr("Owner");
    address internal SUPPLIER = makeAddr("Supplier");
    address internal BORROWER = makeAddr("Borrower");
    address internal REPAYER = makeAddr("Repayer");
    address internal ONBEHALF = makeAddr("OnBehalf");
    address internal RECEIVER = makeAddr("Receiver");
    address internal ALLOCATOR = makeAddr("Allocator");
    address internal CURATOR = makeAddr("Curator");
    address internal GUARDIAN = makeAddr("Guardian");
    address internal FEE_RECIPIENT = makeAddr("FeeRecipient");
    address internal SKIM_RECIPIENT = makeAddr("SkimRecipient");
    address internal MORPHO_OWNER = makeAddr("MorphoOwner");
    address internal MORPHO_FEE_RECIPIENT = makeAddr("MorphoFeeRecipient");

    IMorpho internal morpho = IMorpho(deployCode("Morpho.sol", abi.encode(MORPHO_OWNER)));
    ERC20Mock internal loanToken = new ERC20Mock("loan", "B");
    ERC20Mock internal collateralToken = new ERC20Mock("collateral", "C");
    OracleMock internal oracle = new OracleMock();
    IrmMock internal irm = new IrmMock();

    MarketParams[] internal allMarkets;
    MarketParams internal idleParams;

    function setUp() public virtual {
        vm.label(address(morpho), "Morpho");
        vm.label(address(loanToken), "Loan");
        vm.label(address(collateralToken), "Collateral");
        vm.label(address(oracle), "Oracle");
        vm.label(address(irm), "Irm");

        oracle.setPrice(ORACLE_PRICE_SCALE);

        irm.setApr(0.5 ether); // 50%.

        idleParams = MarketParams({
            loanToken: address(loanToken),
            collateralToken: address(0),
            oracle: address(0),
            irm: address(irm),
            lltv: 0
        });

        vm.startPrank(MORPHO_OWNER);
        morpho.enableIrm(address(irm));
        morpho.setFeeRecipient(MORPHO_FEE_RECIPIENT);

        morpho.enableLltv(0);
        vm.stopPrank();

        morpho.createMarket(idleParams);

        for (uint256 i; i < NB_MARKETS; ++i) {
            uint256 lltv = 0.8 ether / (i + 1);

            MarketParams memory marketParams = MarketParams({
                loanToken: address(loanToken),
                collateralToken: address(collateralToken),
                oracle: address(oracle),
                irm: address(irm),
                lltv: lltv
            });

            vm.prank(MORPHO_OWNER);
            morpho.enableLltv(lltv);

            morpho.createMarket(marketParams);

            allMarkets.push(marketParams);
        }

        allMarkets.push(idleParams); // Must be pushed last.

        vm.startPrank(SUPPLIER);
        loanToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);
        vm.stopPrank();

        vm.prank(BORROWER);
        collateralToken.approve(address(morpho), type(uint256).max);

        vm.prank(REPAYER);
        loanToken.approve(address(morpho), type(uint256).max);
    }

    /// @dev Rolls & warps the given number of blocks forward the blockchain.
    function _forward(uint256 blocks) internal {
        vm.roll(block.number + blocks);
        vm.warp(block.timestamp + blocks * BLOCK_TIME); // Block speed should depend on test network.
    }

    /// @dev Bounds the fuzzing input to a realistic number of blocks.
    function _boundBlocks(uint256 blocks) internal pure returns (uint256) {
        return bound(blocks, 2, type(uint24).max);
    }

    /// @dev Bounds the fuzzing input to a non-zero address.
    /// @dev This function should be used in place of `vm.assume` in invariant test handler functions:
    /// https://github.com/foundry-rs/foundry/issues/4190.
    function _boundAddressNotZero(address input) internal view virtual returns (address) {
        return address(uint160(bound(uint256(uint160(input)), 1, type(uint160).max)));
    }

    function _accrueInterest(MarketParams memory market) internal {
        collateralToken.setBalance(address(this), 1);
        morpho.supplyCollateral(market, 1, address(this), hex"");
        morpho.withdrawCollateral(market, 1, address(this), address(10));
    }

    /// @dev Returns a random market params from the list of markets enabled on Blue (except the idle market).
    function _randomMarketParams(uint256 seed) internal view returns (MarketParams memory) {
        return allMarkets[seed % (allMarkets.length - 1)];
    }

    function _randomCandidate(address[] memory candidates, uint256 seed) internal pure returns (address) {
        if (candidates.length == 0) return address(0);

        return candidates[seed % candidates.length];
    }

    function _removeAll(address[] memory inputs, address removed) internal pure returns (address[] memory result) {
        result = new address[](inputs.length);

        uint256 nbAddresses;
        for (uint256 i; i < inputs.length; ++i) {
            address input = inputs[i];

            if (input != removed) {
                result[nbAddresses] = input;
                ++nbAddresses;
            }
        }

        assembly {
            mstore(result, nbAddresses)
        }
    }

    function _randomNonZero(address[] memory users, uint256 seed) internal pure returns (address) {
        users = _removeAll(users, address(0));

        return _randomCandidate(users, seed);
    }
}
