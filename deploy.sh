#!/bin/bash

set -e

network=$1

echo "Starting Deployment on $network"

if [ $network == "testnet" ]; then
    npx hardhat deploy --network europa-testnet --tags LibTypesV1,LibFeeCalculatorV1,SKALEStation,USDCs
    # npx hardhat deploy --network aurora-testnet --tags Station,USDC
    npx hardhat deploy --network amoy-testnet --tags LibTypesV1,SatelliteStation,USDC
    npx hardhat lz:oapp:wire --oapp-config layerzero.config.ts
    npx hardhat run ./tasks/testnet/mapUSDC.ts --network europa-testnet
    # npx hardhat run ./tasks/testnet/mapUSDC.ts --network aurora-testnet
    npx hardhat run ./tasks/testnet/mapUSDC.ts --network amoy-testnet
else
    echo "Mainnet Not yet Supported!" >&2
    exit 1
fi