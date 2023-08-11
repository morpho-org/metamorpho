-include .env
.EXPORT_ALL_VARIABLES:
MAKEFLAGS += --no-print-directory

NETWORK ?= ethereum-mainnet


install:
	foundryup
	forge install

contracts:
	FOUNDRY_TEST=/dev/null FOUNDRY_SCRIPT=/dev/null forge build --via-ir --extra-output-files irOptimized --sizes --force


test-mainnet:
	@FOUNDRY_MATCH_CONTRACT=EthereumTest make test

test-local:
	@FOUNDRY_MATCH_CONTRACT=LocalTest make test

test:
	forge test -vvv


test-%:
	@FOUNDRY_MATCH_TEST=$* make test


test/%:
	@FOUNDRY_MATCH_CONTRACT=$* make test


.PHONY: contracts test
