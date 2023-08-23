// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Id, MarketParams, Signature, Authorization, IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";

import {MarketParamsLib} from "@morpho-blue/libraries/MarketParamsLib.sol";
import {SharesMathLib} from "@morpho-blue/libraries/SharesMathLib.sol";
import {MathLib, WAD} from "@morpho-blue/libraries/MathLib.sol";
import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";
import {MorphoLib} from "@morpho-blue/libraries/periphery/MorphoLib.sol";
import {MorphoBalancesLib} from "@morpho-blue/libraries/periphery/MorphoBalancesLib.sol";

import {Morpho} from "@morpho-blue/Morpho.sol";
import {IrmMock} from "@morpho-blue/mocks/IrmMock.sol";

import "@forge-std/Test.sol";
import "@forge-std/console2.sol";

abstract contract BaseTest is Test {
    using MathLib for uint256;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;
    using SafeTransferLib for ERC20;
    using stdStorage for StdStorage;

    uint256 internal constant MIN_AMOUNT = 1000;
    uint256 internal constant MAX_AMOUNT = 2 ** 64;
    uint256 internal constant ORACLE_PRICE_SCALE = 1e36;

    address internal constant USER = address(0x1234);
    address internal constant SUPPLIER = address(0x5678);
    address internal constant OWNER = address(0xdead);

    IMorpho internal morpho;
    IrmMock internal irm;

    function setUp() public virtual {
        morpho = IMorpho(address(new Morpho(OWNER)));

        irm = new IrmMock(morpho);

        vm.prank(OWNER);
        morpho.enableIrm(address(irm));
    }
}
