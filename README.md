# 🎉 Foundry Raffle Project 🎉

Participate in the **Raffle** to win **ETH**!

---

## **BIG THANKS TO [PATRICK COLLINS](https://twitter.com/PatrickAlphaC) FOR THE GREAT COURSE!**

The contract is deployed on **Sepolia** at the following address:

**Contract Address**: [0x9c576040B27E9FAE20Ec14c0C89097D15D862474](https://sepolia.etherscan.io/address/0x9c576040B27E9FAE20Ec14c0C89097D15D862474)

---

## 🎲 Lottery Details

- **Frequency**: The lottery runs **first of every month**.
- **Mechanism**:
  - The system checks if `checkUpkeep` returns `true` in the `performUpkeep` function.
  - If `true`, the function executes and a **random winner** is selected.

---

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
