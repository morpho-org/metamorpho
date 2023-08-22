// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Config, ConfigMarket, ConfigLib} from "./ConfigLib.sol";

import {StdChains, VmSafe} from "@forge-std/StdChains.sol";

abstract contract Configured is StdChains {
    using ConfigLib for Config;

    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    Config internal config;

    address internal dai;
    address internal usdc;
    address internal usdt;
    address internal link;
    address internal wbtc;
    address internal weth;
    address internal wNative;
    address[] internal lsdNatives;
    address[] internal allAssets;

    ConfigMarket[] internal configMarkets;

    function _network() internal view virtual returns (string memory);

    function _rpcAlias() internal virtual returns (string memory) {
        return config.getRpcAlias();
    }

    function _initConfig() internal returns (Config storage) {
        if (bytes(config.json).length == 0) {
            string memory root = vm.projectRoot();
            string memory path = string.concat(root, "/config/", _network(), ".json");

            config.json = vm.readFile(path);
        }

        return config;
    }

    function _loadConfig() internal virtual {
        dai = config.getAddress("DAI");
        usdc = config.getAddress("USDC");
        usdt = config.getAddress("USDT");
        link = config.getAddress("LINK");
        wbtc = config.getAddress("WBTC");
        weth = config.getAddress("WETH");
        wNative = config.getWrappedNative();
        lsdNatives = config.getLsdNatives();

        allAssets = [dai, usdc, usdt, link, wbtc, weth];

        configMarkets = config.getMarkets();

        for (uint256 i; i < lsdNatives.length; ++i) {
            allAssets.push(lsdNatives[i]);
        }
    }
}
