// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {IMorphoMarketParams} from "contracts/interfaces/IMorphoMarketParams.sol";

import {IrmMock as Irm} from "contracts/mocks/IrmMock.sol";
import {ERC20Mock as ERC20} from "contracts/mocks/ERC20Mock.sol";
import {OracleMock as Oracle} from "contracts/mocks/OracleMock.sol";

import {SupplyVault, IERC20, ErrorsLib, Pending, MarketAllocation} from "contracts/SupplyVault.sol";
import {Morpho, MarketParamsLib, MarketParams, SharesMathLib, Id} from "@morpho-blue/Morpho.sol";

contract BaseTest is Test {
    using MarketParamsLib for MarketParams;

    uint256 internal constant HIGH_COLLATERAL_AMOUNT = 1e35;
    uint256 internal constant MIN_TEST_AMOUNT = 100;
    uint256 internal constant MAX_TEST_AMOUNT = 1e28;
    uint256 internal constant MIN_TEST_SHARES = MIN_TEST_AMOUNT * SharesMathLib.VIRTUAL_SHARES;
    uint256 internal constant MAX_TEST_SHARES = MAX_TEST_AMOUNT * SharesMathLib.VIRTUAL_SHARES;
    uint256 internal constant MIN_COLLATERAL_PRICE = 1e10;
    uint256 internal constant MAX_COLLATERAL_PRICE = 1e40;
    uint256 internal constant MAX_COLLATERAL_ASSETS = type(uint128).max;
    uint256 internal constant NB_OF_MARKETS = 10;

    address internal SUPPLIER = _addrFromHashedString("Morpho Supplier");
    address internal BORROWER = _addrFromHashedString("Morpho Borrower");
    address internal REPAYER = _addrFromHashedString("Morpho Repayer");
    address internal ONBEHALF = _addrFromHashedString("Morpho On Behalf");
    address internal RECEIVER = _addrFromHashedString("Morpho Receiver");
    address internal LIQUIDATOR = _addrFromHashedString("Morpho Liquidator");
    address internal OWNER = _addrFromHashedString("Morpho Owner");
    address internal RISK_MANAGER = _addrFromHashedString("Morpho Risk Manager");
    address internal ALLOCATOR = _addrFromHashedString("Morpho Allocator");

    uint256 internal constant LLTV = 0.8 ether;
    uint256 internal constant TIMELOCK = 0;
    uint128 internal constant CAP = type(uint128).max;

    Morpho internal morpho;
    ERC20 internal borrowableToken;
    ERC20 internal collateralToken;
    Oracle internal oracle;
    Irm internal irm;
    MarketParams internal marketParams;

    SupplyVault internal vault;

    MarketParams[] internal allMarkets;

    function setUp() public virtual {
        vm.label(OWNER, "Owner");
        vm.label(SUPPLIER, "Supplier");
        vm.label(BORROWER, "Borrower");
        vm.label(REPAYER, "Repayer");
        vm.label(ONBEHALF, "OnBehalf");
        vm.label(RECEIVER, "Receiver");
        vm.label(LIQUIDATOR, "Liquidator");

        // Create Morpho.
        morpho = new Morpho(OWNER);
        vm.label(address(morpho), "Morpho");

        // List a market.
        borrowableToken = new ERC20("borrowable", "B");
        vm.label(address(borrowableToken), "Borrowable asset");

        collateralToken = new ERC20("collateral", "C");
        vm.label(address(collateralToken), "Collateral asset");

        oracle = new Oracle();
        vm.label(address(oracle), "Oracle");

        oracle.setPrice(1e36);

        irm = new Irm();
        vm.label(address(irm), "IRM");

        marketParams =
            MarketParams(address(borrowableToken), address(collateralToken), address(oracle), address(irm), LLTV);

        vm.startPrank(OWNER);

        vault = new SupplyVault(address(morpho), TIMELOCK, IERC20(address(borrowableToken)), "MetaMorpho Vault", "MMV");

        morpho.enableIrm(address(irm));

        for (uint256 i; i < NB_OF_MARKETS; i++) {
            morpho.enableLltv(LLTV / (i + 1));
            marketParams = MarketParams(
                address(borrowableToken), address(collateralToken), address(oracle), address(irm), LLTV / (i + 1)
            );
            morpho.createMarket(marketParams);

            allMarkets.push(marketParams);
        }

        vault.setIsRiskManager(RISK_MANAGER, true);
        vault.setIsAllocator(ALLOCATOR, true);

        vm.stopPrank();

        vm.warp(block.timestamp + 1);
    }

    function _addrFromHashedString(string memory str) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(str)))));
    }

    function _submitAndSetTimelock(uint128 timelock) internal {
        vm.startPrank(OWNER);
        vault.submitPendingTimelock(timelock);
        vm.warp(block.timestamp + vault.timelock());
        vault.setTimelock();
        vm.stopPrank();
    }

    function _submitAndEnableMarket(MarketParams memory params, uint128 cap) internal {
        vm.startPrank(RISK_MANAGER);
        vault.submitPendingMarket(params, cap);
        vm.warp(block.timestamp + vault.timelock());
        vault.enableMarket(params.id());
        vm.stopPrank();
    }
}
