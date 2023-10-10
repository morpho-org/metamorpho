// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@morpho-blue/interfaces/IMorpho.sol";

import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";
import {MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

import "src/libraries/ConstantsLib.sol";
import {ORACLE_PRICE_SCALE} from "@morpho-blue/libraries/ConstantsLib.sol";

import {IrmMock} from "src/mocks/IrmMock.sol";
import {ERC20Mock} from "src/mocks/ERC20Mock.sol";
import {OracleMock} from "src/mocks/OracleMock.sol";

import {MetaMorpho, IMetaMorpho, ERC20, IERC20, ErrorsLib, MarketAllocation, SharesMathLib} from "src/MetaMorpho.sol";

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";

uint256 constant MIN_TEST_ASSETS = 1e8;
uint256 constant MAX_TEST_ASSETS = 1e28;
uint256 constant NB_MARKETS = MAX_QUEUE_SIZE + 1;
uint192 constant CAP = type(uint192).max;

contract InternalTest is Test, MetaMorpho {
    using MorphoLib for IMorpho;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using stdJson for string;

    address internal OWNER = makeAddr("Owner");
    address internal SUPPLIER = makeAddr("Supplier");
    address internal ALLOCATOR = makeAddr("Allocator");
    address internal RISK_MANAGER = makeAddr("RiskManager");
    address internal MORPHO_OWNER = makeAddr("MorphoOwner");
    address internal MORPHO_FEE_RECIPIENT = makeAddr("MorphoFeeRecipient");

    IMorpho internal morpho = IMorpho(_deploy("lib/morpho-blue/out/Morpho.sol/Morpho.json", abi.encode(MORPHO_OWNER)));
    ERC20Mock internal loanToken = new ERC20Mock("loan", "B");
    ERC20Mock internal collateralToken;
    OracleMock internal oracle;
    IrmMock internal irm;

    MarketParams[] internal allMarkets;

    constructor() MetaMorpho(OWNER, address(morpho), 0, address(loanToken), "MetaMorpho Vault", "MM") {}

    function setUp() public virtual {
        vm.label(address(morpho), "Morpho");
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

        changePrank(OWNER);
        IMetaMorpho(address(this)).setRiskManager(RISK_MANAGER);
        IMetaMorpho(address(this)).setIsAllocator(ALLOCATOR, true);
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

        vm.startPrank(SUPPLIER);
        loanToken.approve(address(this), type(uint256).max);
        collateralToken.approve(address(this), type(uint256).max);
        loanToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);
        vm.stopPrank();
    }

    function _deploy(string memory artifactPath, bytes memory constructorArgs) internal returns (address deployed) {
        string memory artifact = vm.readFile(artifactPath);
        bytes memory bytecode = bytes.concat(artifact.readBytes("$.bytecode.object"), constructorArgs);

        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        require(deployed != address(0), string.concat("could not deploy `", artifactPath, "`"));
    }

    function testSetCapMaxQueueSizeExcedeed() public {
        for (uint256 i; i < NB_MARKETS - 1; ++i) {
            Id id = allMarkets[i].id();
            _setCap(id, CAP);
        }

        Id lsastId = allMarkets[NB_MARKETS - 1].id();
        vm.expectRevert(ErrorsLib.MaxQueueSizeExceeded.selector);
        _setCap(lsastId, CAP);
    }

    function testSuppliableNotEnabledMarket() public {
        Id id = allMarkets[0].id();
        uint256 suppliable = _suppliable(allMarkets[0], id);

        assertEq(suppliable, 0, "suppliable");
    }

    function testSuppliableEnabledMarket(uint256 suppliedAmount) public {
        suppliedAmount = bound(suppliedAmount, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        Id id = allMarkets[0].id();
        _setCap(id, CAP);

        loanToken.setBalance(SUPPLIER, suppliedAmount);
        vm.prank(SUPPLIER);
        IMetaMorpho(address(this)).deposit(suppliedAmount, SUPPLIER);

        uint256 suppliable = _suppliable(allMarkets[0], id);

        assertEq(suppliable, CAP - suppliedAmount, "suppliable");
    }

    function testWithdrawable(uint256 suppliedAmount) public {
        suppliedAmount = bound(suppliedAmount, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        Id id = allMarkets[0].id();
        _setCap(id, CAP);

        loanToken.setBalance(SUPPLIER, suppliedAmount);
        vm.prank(SUPPLIER);
        IMetaMorpho(address(this)).deposit(suppliedAmount, SUPPLIER);

        uint256 withdrawable = _withdrawable(allMarkets[0], id);

        uint256 supplyShares = MORPHO.supplyShares(id, address(this));
        (uint256 totalSupplyAssets, uint256 totalSupplyShares,,) = MORPHO.expectedMarketBalances(allMarkets[0]);
        uint256 expectedWithdrawable = supplyShares.toAssetsDown(totalSupplyAssets, totalSupplyShares);

        assertEq(withdrawable, expectedWithdrawable, "withdrawable");
    }
}
