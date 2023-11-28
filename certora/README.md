This folder contains the verification of MetaMorpho using CVL, Certora's Verification Language.

# High-level description

A MetaMorpho vault is an ERC4626 vault that defines a list of Morpho Blue market to allocate its funds.

# Folder and file structure

The [`certora/specs`](specs) folder contains the following files:

TODO

The [`certora/confs`](confs) folder contains a configuration file for each corresponding specification file.

The [`certora/harness`](harness) folder contains contracts that enable the verification of MetaMorpho.
Notably, this allows handling the fact that library functions should be called from a contract to be verified independently, and it allows defining needed getters.

The [`certora/dispatch`](dispatch) folder contains different contracts similar to the ones that are expected to be called from MetaMorpho.

# Getting started

Install `certora-cli` package with `pip install certora-cli`.
To verify specification files, pass to `certoraRun` the corresponding configuration file in the [`certora/confs`](confs) folder.
It requires having set the `CERTORAKEY` environment variable to a valid Certora key.
You can also pass additional arguments, notably to verify a specific rule.
For example, at the root of the repository:

TODO

The `certora-cli` package also includes a `certoraMutate` binary.
The file [`gambit.conf`](gambit.conf) provides a default configuration of the mutations.
You can test to mutate the code and check it against a particular specification.
For example, at the root of the repository:

TODO
