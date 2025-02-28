import assert from 'assert'

import { type DeployFunction } from 'hardhat-deploy/types'

import { EndpointId } from '@layerzerolabs/lz-definitions'

// TODO declare your contract name here
const contractName = 'OFTBridge'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)
    
    const feeManager = await hre.deployments.get("FeeManager");

    const { address } = await deploy(contractName, {
        from: deployer,
        args: [
            deployer,
            feeManager.address
        ],
        libraries: {
            LibTypesV1: (await deployments.get('LibTypesV1')).address,
        },
        log: true,
        skipIfAlreadyDeployed: true,
    })

    console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${address}`)
}

deploy.tags = [contractName]

export default deploy
