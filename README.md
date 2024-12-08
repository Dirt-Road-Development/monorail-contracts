# Monorail Contracts

## Installation

Run clone the repo and run `nvm install && nvm use && npm install` if you have nvm installed.
If you don't ensure that you have the proper version in .nvmrc set and run
`npm install`.

## Deployment

### SKALE Europa Testnet

1. `npx hardhat deploy --network europa-testnet --tags FeeManager`
2. `npx hardhat deploy --network europa-testnet --tags SKALEStation`

## Non EVM Testnet

1. `npx hardhat deploy --network <network-name> --tags FeeManager`
2. `npx hardhat deploy --network <network-name> --tags Station`

## Non Europa SKALE Chain

Coming Soon...