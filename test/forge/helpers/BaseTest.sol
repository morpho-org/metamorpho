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

import {MetaMorpho, IERC20, ErrorsLib, MarketAllocation} from "src/MetaMorpho.sol";

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";

uint256 constant BLOCK_TIME = 1;
uint256 constant MIN_TEST_ASSETS = 1e8;
uint256 constant MAX_TEST_ASSETS = 1e28;
uint256 constant NB_MARKETS = 10;
uint128 constant CAP = type(uint128).max;

contract BaseTest is Test {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;
    using stdJson for string;

    address internal OWNER;
    address internal SUPPLIER;
    address internal BORROWER;
    address internal REPAYER;
    address internal ONBEHALF;
    address internal RECEIVER;
    address internal ALLOCATOR;
    address internal RISK_MANAGER;
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
        OWNER = _addrFromHashedString("Owner");
        SUPPLIER = _addrFromHashedString("Supplier");
        BORROWER = _addrFromHashedString("Borrower");
        REPAYER = _addrFromHashedString("Repayer");
        ONBEHALF = _addrFromHashedString("OnBehalf");
        RECEIVER = _addrFromHashedString("Receiver");
        ALLOCATOR = _addrFromHashedString("Allocator");
        RISK_MANAGER = _addrFromHashedString("RiskManager");
        MORPHO_OWNER = _addrFromHashedString("MorphoOwner");
        MORPHO_FEE_RECIPIENT = _addrFromHashedString("MorphoFeeRecipient");

        morpho = IMorpho(_deploy("lib/morpho-blue/out/Morpho.sol/Morpho.json", abi.encode(MORPHO_OWNER)));
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
        vm.stopPrank();

        vault = new MetaMorpho(OWNER, address(morpho), 0, address(loanToken), "MetaMorpho Vault", "MMV");

        vm.startPrank(OWNER);
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

    function _addrFromHashedString(string memory name) internal returns (address addr) {
        addr = address(uint160(uint256(keccak256(bytes(name)))));
        vm.label(addr, name);
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

    function neq(MarketParams memory a, MarketParams memory b) internal pure returns (bool) {
        return (Id.unwrap(a.id()) != Id.unwrap(b.id()));
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

    function _deploy(string memory artifactPath, bytes memory constructorArgs) internal returns (address deployed) {
        string memory artifact = vm.readFile(artifactPath);
        bytes memory bytecode = bytes.concat(artifact.readBytes("$.bytecode.object"), constructorArgs);

        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        require(deployed != address(0), string.concat("could not deploy `", artifactPath, "`"));
    }

    function _setTimelock(uint256 newTimelock) internal {
        uint256 timelock = vault.timelock();
        if (newTimelock == timelock) return;

        vm.prank(OWNER);
        vault.submitTimelock(newTimelock);

        if (newTimelock > timelock || timelock == 0) return;

        vm.warp(block.timestamp + timelock);

        vm.prank(OWNER);
        vault.acceptTimelock();
    }

    function _setFee(uint256 newFee) internal {
        uint256 fee = vault.fee();
        if (newFee == fee) return;

        vm.prank(OWNER);
        vault.submitFee(newFee);

        uint256 timelock = vault.timelock();
        if (newFee < fee || timelock == 0) return;

        vm.warp(block.timestamp + timelock);

        vm.prank(OWNER);
        vault.acceptFee();
    }

    function _setCap(MarketParams memory marketParams, uint256 newCap) internal {
        Id id = marketParams.id();
        (uint256 cap,) = vault.config(id);
        if (newCap == cap) return;

        vm.prank(RISK_MANAGER);
        vault.submitCap(marketParams, newCap);

        uint256 timelock = vault.timelock();
        if (newCap < cap || timelock == 0) return;

        vm.warp(block.timestamp + timelock);

        vm.prank(RISK_MANAGER);
        vault.acceptCap(id);
    }
}
