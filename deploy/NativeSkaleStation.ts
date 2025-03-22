import assert from 'assert'

import { type DeployFunction } from 'hardhat-deploy/types'

// TODO declare your contract name here
const contractName = 'NativeSkaleStation'

const deploy: DeployFunction = async (hre) => {
    const { getNamedAccounts, deployments } = hre

    const { deploy } = deployments
    const { deployer } = await getNamedAccounts()

    assert(deployer, 'Missing named deployer account')

    console.log(`Network: ${hre.network.name}`)
    console.log(`Deployer: ${deployer}`)
    
    const endpointV2Deployment = await hre.deployments.get('EndpointV2')
    const feeManager = await hre.deployments.get("FeeManager");
    const interchainRegistry = await hre.deployments.get("InterchainRegistry");

    const { address } = await deploy(contractName, {
        from: deployer,
        args: [
            endpointV2Deployment.address, // LayerZero's EndpointV2 address
            deployer,
            feeManager.address, // Switch to Multisig in Production
            interchainRegistry.address,
            "0xD2aAA00500000000000000000000000000000000"
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
