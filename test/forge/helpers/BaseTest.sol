// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@morpho-blue/interfaces/IMorpho.sol";

import {WAD, MathLib} from "@morpho-blue/libraries/MathLib.sol";
import {Math} from "@openzeppelin/utils/math/Math.sol";
import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";
import {MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

import "src/libraries/ConstantsLib.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";

import {IrmMock} from "src/mocks/IrmMock.sol";
import {ERC20Mock} from "src/mocks/ERC20Mock.sol";
import {OracleMock} from "src/mocks/OracleMock.sol";

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {MetaMorpho, ERC20, IERC20, ErrorsLib, MarketAllocation} from "src/MetaMorpho.sol";

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";

uint256 constant BLOCK_TIME = 1;
uint256 constant MIN_TEST_ASSETS = 1e8;
uint256 constant MAX_TEST_ASSETS = 1e28;
uint256 constant NB_MARKETS = 10;
uint256 constant CAP = type(uint128).max;

contract BaseTest is Test {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    address internal OWNER;
    address internal SUPPLIER;
    address internal BORROWER;
    address internal REPAYER;
    address internal ONBEHALF;
    address internal RECEIVER;
    address internal ALLOCATOR;
    address internal RISK_MANAGER;
    address internal GUARDIAN;
    address internal FEE_RECIPIENT;
    address internal MORPHO_OWNER;
    address internal MORPHO_FEE_RECIPIENT;

    IMorpho internal morpho;
    ERC20Mock internal loanToken;
    ERC20Mock internal collateralToken;
    OracleMock internal oracle;
    IrmMock internal irm;

    MetaMorpho internal vault;

    MarketParams[] internal allMarkets;

    function setUp() public virtual {
        OWNER = makeAddr("Owner");
        SUPPLIER = makeAddr("Supplier");
        BORROWER = makeAddr("Borrower");
        REPAYER = makeAddr("Repayer");
        ONBEHALF = makeAddr("OnBehalf");
        RECEIVER = makeAddr("Receiver");
        ALLOCATOR = makeAddr("Allocator");
        RISK_MANAGER = makeAddr("RiskManager");
        GUARDIAN = makeAddr("Guardian");
        FEE_RECIPIENT = makeAddr("FeeRecipient");
        MORPHO_OWNER = makeAddr("MorphoOwner");
        MORPHO_FEE_RECIPIENT = makeAddr("MorphoFeeRecipient");

        morpho = IMorpho(deployCode("lib/morpho-blue/out/Morpho.sol/Morpho.json", abi.encode(MORPHO_OWNER)));
        vm.label(address(morpho), "Morpho");

        loanToken = new ERC20Mock("loan", "B");
        vm.label(address(loanToken), "Loan");

        collateralToken = new ERC20Mock("collateral", "C");
        vm.label(address(collateralToken), "Collateral");

        oracle = new OracleMock();
        vm.label(address(oracle), "Oracle");

        oracle.setPrice(ORACLE_PRICE_SCALE);

        irm = new IrmMock();

        irm.setApr(0.5 ether); // 50%.

        vm.startPrank(MORPHO_OWNER);
        morpho.enableIrm(address(irm));
        morpho.setFeeRecipient(MORPHO_FEE_RECIPIENT);

        vault = new MetaMorpho(OWNER, address(morpho), MIN_TIMELOCK, address(loanToken), "MetaMorpho Vault", "MMV");

        changePrank(OWNER);
        vault.setRiskManager(RISK_MANAGER);
        vault.setIsAllocator(ALLOCATOR, true);
        vm.stopPrank();

        for (uint256 i; i < NB_MARKETS; ++i) {
            uint256 lltv = 0.8 ether / (i + 1);

            MarketParams memory marketParams = MarketParams({
                loanToken: address(loanToken),
                collateralToken: address(collateralToken),
                oracle: address(oracle),
                irm: address(irm),
                lltv: lltv
            });

            vm.startPrank(MORPHO_OWNER);
            morpho.enableLltv(lltv);
            morpho.createMarket(marketParams);
            vm.stopPrank();

            allMarkets.push(marketParams);
        }

        loanToken.approve(address(vault), type(uint256).max);
        collateralToken.approve(address(vault), type(uint256).max);

        vm.startPrank(SUPPLIER);
        loanToken.approve(address(vault), type(uint256).max);
        collateralToken.approve(address(vault), type(uint256).max);
        loanToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);
        vm.stopPrank();

        vm.prank(BORROWER);
        collateralToken.approve(address(morpho), type(uint256).max);

        vm.prank(REPAYER);
        loanToken.approve(address(morpho), type(uint256).max);

        vm.startPrank(ONBEHALF);
        loanToken.approve(address(vault), type(uint256).max);
        collateralToken.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    /// @dev Rolls & warps the given number of blocks forward the blockchain.
    function _forward(uint256 blocks) internal {
        vm.roll(block.number + blocks);
        vm.warp(block.timestamp + blocks * BLOCK_TIME); // Block speed should depend on test network.
    }

    /// @dev Bounds the fuzzing input to a realistic number of blocks.
    function _boundBlocks(uint256 blocks) internal view returns (uint256) {
        return bound(blocks, 1, type(uint24).max);
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

    function _randomMarketParams(uint256 seed) internal view returns (MarketParams memory) {
        return allMarkets[seed % allMarkets.length];
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

    function _setTimelock(uint256 newTimelock) internal {
        uint256 timelock = vault.timelock();
        if (newTimelock == timelock) return;

        // block.timestamp defaults to 1 which may lead to an unrealistic state: block.timestamp < timelock.
        if (block.timestamp < timelock) vm.warp(block.timestamp + timelock);

        vm.prank(OWNER);
        vault.submitTimelock(newTimelock);

        if (newTimelock > timelock || timelock == 0) return;

        vm.warp(block.timestamp + timelock);

        vault.acceptTimelock();

        assertEq(vault.timelock(), newTimelock, "_setTimelock");
    }

    function _setGuardian(address newGuardian) internal {
        address guardian = vault.guardian();
        if (newGuardian == guardian) return;

        vm.prank(OWNER);
        vault.submitGuardian(newGuardian);

        uint256 timelock = vault.timelock();
        if (guardian == address(0) || timelock == 0) return;

        vm.warp(block.timestamp + timelock);

        vault.acceptGuardian();

        assertEq(vault.guardian(), newGuardian, "_setGuardian");
    }

    function _setFee(uint256 newFee) internal {
        uint256 fee = vault.fee();
        if (newFee == fee) return;

        vm.prank(OWNER);
        vault.submitFee(newFee);

        uint256 timelock = vault.timelock();
        if (newFee < fee || timelock == 0) return;

        vm.warp(block.timestamp + timelock);

        vault.acceptFee();

        assertEq(vault.fee(), newFee, "_setFee");
    }

    function _setCap(MarketParams memory marketParams, uint256 newCap) internal {
        Id id = marketParams.id();
        (uint256 cap,) = vault.config(id);
        if (newCap == cap) return;

        vm.prank(RISK_MANAGER);
        vault.submitCap(marketParams, newCap);

        uint256 timelock = vault.timelock();
        if (newCap < cap) return;

        vm.warp(block.timestamp + timelock);

        vault.acceptCap(id);

        (cap,) = vault.config(id);

        assertEq(cap, newCap, "_setCap");
    }
}
