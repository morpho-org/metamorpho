-include .env
.EXPORT_ALL_VARIABLES:
MAKEFLAGS += --no-print-directory

NETWORK ?= ethereum-mainnet


install:
	foundryup
	forge install

blue:
	cd lib/morpho-blue/ && FOUNDRY_TEST=/dev/null FOUNDRY_SCRIPT=/dev/null forge build --via-ir

contracts:
	FOUNDRY_TEST=/dev/null FOUNDRY_SCRIPT=/dev/null forge build --via-ir --extra-output-files irOptimized --sizes --force


test-mainnet:
	@FOUNDRY_MATCH_CONTRACT=EthereumTest make test

test-local:
	@FOUNDRY_MATCH_CONTRACT=LocalTest make test

test: blue
	forge test -vvv


test-%:
	@FOUNDRY_MATCH_TEST=$* make test


test/%:
	@FOUNDRY_MATCH_CONTRACT=$* make test


.PHONY: contracts test
