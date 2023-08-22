// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// import {SigUtils} from "@morpho-blue/../test/helpers/SigUtils.sol";
import {IMorpho, MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";

import "@morpho-blue/Morpho.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {OracleMock} from "@morpho-blue/mocks/OracleMock.sol";
import {IrmMock} from "@morpho-blue/mocks/IrmMock.sol";

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";

contract BaseBundlerTest is Test {
    using MathLib for uint256;
    using MorphoLib for IMorpho;
    using MarketLib for MarketParams;
    using SharesMathLib for uint256;
    using stdStorage for StdStorage;

    uint256 internal constant MIN_AMOUNT = 1000;
    uint256 internal constant MAX_AMOUNT = 2 ** 64;
    uint256 internal constant ORACLE_SCALE = 1e36;

    address internal OWNER = _addrFromHashedString("Morpho Liquidator");
    address internal USER = _addrFromHashedString("Morpho User");
    address internal SUPPLIER = _addrFromHashedString("Morpho Supplier");
    address internal RECEIVER = _addrFromHashedString("Morpho Receiver");
    address internal LIQUIDATOR = _addrFromHashedString("Morpho Liquidator");

    uint256 internal constant LLTV = 0.8 ether;

    IMorpho internal morpho;
    ERC20Mock internal borrowableToken;
    ERC20Mock internal collateralToken;
    OracleMock internal oracle;
    IrmMock internal irm;
    MarketParams internal marketParams;
    Id internal id;

    function setUp() public virtual {
        vm.label(OWNER, "Owner");
        vm.label(USER, "User");
        vm.label(SUPPLIER, "Supplier");
        vm.label(RECEIVER, "Receiver");
        vm.label(LIQUIDATOR, "Liquidator");

        // Create Morpho.
        morpho = IMorpho(address(new Morpho(OWNER)));

        // List a marketParams.
        borrowableToken = new ERC20Mock("borrowable", "B", 18);
        collateralToken = new ERC20Mock("collateral", "C", 18);
        oracle = new OracleMock();

        irm = new IrmMock(morpho);

        marketParams =
            MarketParams(address(borrowableToken), address(collateralToken), address(oracle), address(irm), LLTV);
        id = marketParams.id();

        vm.startPrank(OWNER);
        morpho.enableIrm(address(irm));
        morpho.enableLltv(LLTV);
        morpho.createMarket(marketParams);
        vm.stopPrank();

        oracle.setPrice(ORACLE_SCALE);

        borrowableToken.approve(address(morpho), type(uint256).max);
        collateralToken.approve(address(morpho), type(uint256).max);
    }

    function _addrFromHashedString(string memory str) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(str)))));
    }
}
