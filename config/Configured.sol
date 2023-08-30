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
    address internal WNATIVE;
    address[] internal lsdNatives;
    address[] internal allAssets;
    address internal aaveV3Pool;
    address internal aaveV2LendingPool;

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
        aaveV3Pool = config.getAddress("aaveV3Pool");
        aaveV2LendingPool = config.getAddress("aaveV2LendingPool");
    }
}
