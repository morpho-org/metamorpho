// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Config, ConfigMarket, ConfigLib} from "./ConfigLib.sol";

import {StdChains, VmSafe} from "@forge-std/StdChains.sol";

abstract contract Configured is StdChains {
    using ConfigLib for Config;

    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    Config internal CONFIG;

    address internal DAI;
    address internal USDC;
    address internal USDT;
    address internal LINK;
    address internal WBTC;
    address internal WETH;
    address internal CB_ETH;
    address internal WNATIVE;
    address[] internal lsdNatives;
    address[] internal allAssets;

    address internal AAVE_V2_POOL;
    address internal AAVE_V3_POOL;
    address internal AAVE_V3_OPTIMIZER;
    address internal COMPTROLLER;
    address internal C_DAI_V2;
    address internal C_ETH_V2;
    address internal C_USDC_V2;
    address internal C_WETH_V3;

    ConfigMarket[] internal configMarkets;

    function _network() internal view virtual returns (string memory);

    function _rpcAlias() internal virtual returns (string memory) {
        return CONFIG.getRpcAlias();
    }

    function _initConfig() internal returns (Config storage) {
        if (bytes(CONFIG.json).length == 0) {
            string memory root = vm.projectRoot();
            string memory path = string.concat(root, "/config/", _network(), ".json");

            CONFIG.json = vm.readFile(path);
        }

        return CONFIG;
    }

    function _loadConfig() internal virtual {
        DAI = CONFIG.getAddress("DAI");
        USDC = CONFIG.getAddress("USDC");
        USDT = CONFIG.getAddress("USDT");
        LINK = CONFIG.getAddress("LINK");
        WBTC = CONFIG.getAddress("WBTC");
        WETH = CONFIG.getAddress("WETH");
        CB_ETH = CONFIG.getAddress("cbETH");
        WNATIVE = CONFIG.getWrappedNative();

        lsdNatives = CONFIG.getLsdNatives();
        allAssets = [DAI, USDC, USDT, LINK, WBTC, WETH];

        ConfigMarket[] memory allConfigMarkets = CONFIG.getMarkets();
        for (uint256 i; i < allConfigMarkets.length; ++i) {
            configMarkets.push(allConfigMarkets[i]);
        }

        for (uint256 i; i < lsdNatives.length; ++i) {
            allAssets.push(lsdNatives[i]);
        }
        AAVE_V3_POOL = CONFIG.getAddress("aaveV3Pool");
        AAVE_V2_POOL = CONFIG.getAddress("aaveV2Pool");
        AAVE_V3_OPTIMIZER = CONFIG.getAddress("aaveV3Optimizer");
        COMPTROLLER = CONFIG.getAddress("comptroller");
        C_DAI_V2 = CONFIG.getAddress("cDAIv2");
        C_ETH_V2 = CONFIG.getAddress("cETHv2");
        C_USDC_V2 = CONFIG.getAddress("cUSDCv2");
        C_WETH_V3 = CONFIG.getAddress("cWETHv3");
    }
}
