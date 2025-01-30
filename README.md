# SalaamGCC smart contract

This repository provides a comprehensive development environment tailored for the SalaamGCC smart contracts, leveraging
Foundry and a suite of development tools to facilitate a smooth development, testing, and deployment process.

## Features

- [Foundry](https://book.getfoundry.sh/): compile, run, test and deploy smart contracts
- [Solhint](https://github.com/protofire/solhint): to enforce code quality and conformity to Solidity best practices.
- [Prettier Plugin Solidity](https://github.com/prettier-solidity/prettier-plugin-solidity): Adopts Prettier with
  Solidity plugin for consistent code formatting, improving readability and maintainability.
- [Test Coverage](https://github.com/sc-forks/solidity-coverage): Utilize solidity-coverage to measure the coverage of
  your tests, ensuring comprehensive testing of contract functionalities.
- [Contract Sizing](https://github.com/ItsNickBarry/hardhat-contract-sizer): Includes tools to analyze and report the
  size of compiled smart contracts, aiding in optimization and gas usage estimation.

## Project Structure

Organized for clarity and ease of navigation, the project structure supports efficient development practices:

```plaintext
├── script
│   └── SalaamGCCScript.s.sol         # Script for deployment of SalaamGCC token smart contract
├── src
│   └── token
│       └── SalaamGCC.sol             # SalaamGCC token contract
├── test
│   └── token
│       └── SalaamGCC.t.sol           # SalaamGCC token unit test cases
└── foundry.toml                      # Configuration file for forge
```

## Pre Requisites

Before diving into development, ensure you have the following tools and configurations set up:

- **Node.js and npm or bun**: Ensure you have Node.js and npm or bun installed to manage project dependencies.
- **Foundry**: Familiarize yourself with Foundry's workflow and commands for a smooth development experience.
- **Ethereum Wallet**: Have an Ethereum wallet setup, preferably with testnet Ether for deployment and testing.
- **Solidity Knowledge**: A good understanding of Solidity and smart contract development is essential.

## Usage

### Installation

1. **Clone the Repository**: Start by cloning this repository to your local machine.

```sh
git clone [TBD]
```

2. **Navigate to the project directory**

```sh
cd salaamgcc-contracts
```

3. **setup environment**: create .env and copy from .env.example

```sh
PRIVATE_KEY=
ETHERSCAN_API_KEY=
SEPOLIA_RPC_URL=
```

4. **Forge dependencies Install**

```sh
forge install
```

5. **Node dependencies Install**: Install Solhint, Prettier, and other Node.js deps

```sh
bun install
```

or

```sh
npm install
```

### Compile

to build or compile

```sh
forge build
```

### Test

to run all the tests

```sh
forge test
```

### Coverage

```sh
forge coverage
```

### Solhint

```sh
npm run lint:sol
```

### Deploy

Before running the deployment script, ensure that all parameter values are assigned in the deployment script folder.

- **SalaamGCCScript.s.sol**: owner, adminOne, adminTwo, adminThree and minter

1. **Deploy SalaamGCC.sol**

```sh
forge script script/SalaamGCCScript.s.sol:SalaamGCCScript --rpc-url <your_rpc_url> --broadcast
```

### Contract Verification

1. **Verification With Deployment**:This will deploy the contract with verification of the smart contract.

- Example for 'contract_path:Name' : src/token/SalaamGCC.sol:SalaamGCC'

```sh
forge create --rpc-url <your_rpc_url> --constructor-args <constructor_args> --private-key <your_private_key> --etherscan-api-key <etherscan_api_key> --verify <contract_path:Name>
```

2. **Verification After Deployment**:This is for the verification of a smart contract that is pre-existing or already
   deployed. This is example CLI for sepolia chain with >= v0.8.20+commit.a1b79de6 compiler version.

- num-of-optimizations: will default to 0 if not set on verification Ex: 200
- constructor-args: Use Cast’s abi-encode to ABI-encode arguments.
- Example for 'contract_path:Name' : src/token/SalaamGCC.sol:SalaamGCC'
- Example for 'cast_abi_encode_constructor_args': --constructor-args $(cast abi-encode "constructor(address
  "0x0C346b5A32d4d969c5818d784fa1422684fb6A64)
- Example for 'compiler_version': v0.8.20+commit.a1b79de6

```sh
forge verify-contract --chain-id <chain_id> --num-of-optimizations 200 --compiler-version <compiler_version> --constructor-args  <cast_abi_encode_constructor_args> --etherscan-api-key <etherscan_api_key> <contract_address> <contract_path:Name> --watch
```

### Clear

to clear build files

```sh
forge clean
```

### Format

```shell
forge fmt
```

### Gas Snapshots

```shell
forge snapshot
```

### Help

```shell
forge --help
anvil --help
cast --help
```
