#!/bin/bash

set -e

network=$1

echo "Starting Deployment on $network"

if [ $network == "testnet" ]; then

    cd deployments

    rm -rf amoy-testnet
    rm -rf europa-testnet

    cd ..

    npx hardhat deploy --network europa-testnet --tags LibTypesV1,FeeManager,NativeSkaleStation,USDCs
    # npx hardhat deploy --network aurora-testnet --tags Station,USDC
    npx hardhat deploy --network amoy-testnet --tags LibTypesV1,NativeStation,USDC
    npx hardhat lz:oapp:wire --oapp-config layerzero.config.ts
    npx hardhat run ./tasks/testnet/mapUSDC.ts --network europa-testnet
    npx hardhat run ./tasks/testnet/mapUSDC.ts --network amoy-testnet
    # npx hardhat run ./tasks/testnet/mapUSDC.ts --network aurora-testnet
else
    echo "Mainnet Not yet Supported!" >&2
    exit 1
fi

git add .

git commit -am "Prepare Deployment"

sh ./publish.sh