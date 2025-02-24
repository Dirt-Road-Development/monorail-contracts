import { companionNetworks, deployments, ethers, network } from 'hardhat'

import { EndpointId } from '@layerzerolabs/lz-definitions'

async function main() {
    if (network.name === 'europa-testnet') {
        const deploys = await deployments.all()
        const amoyDeployments = await companionNetworks['amoy'].deployments.all()
        const [signer] = await ethers.getSigners()

        const station = new ethers.Contract(deploys['NativeSkaleStation'].address, deploys['NativeSkaleStation'].abi, signer)

        const addToken2 = await station.addToken(
            EndpointId.AMOY_V2_TESTNET,
            amoyDeployments['USDC'].address,
            deploys['USDCs'].address
        )

        await addToken2.wait(1)

        console.log('USDC Added on Europa')
    } else {
        const deploys = await deployments.all()
        const [signer] = await ethers.getSigners()
        const station = new ethers.Contract(
            deploys['NativeStation'].address,
            deploys['NativeStation'].abi,
            signer
        )
        const europaDeployments = await companionNetworks['europa'].deployments.all()

        const addToken = await station.addToken(europaDeployments['USDCs'].address, deploys['USDC'].address)

        await addToken.wait(1)
    }

    console.log('USDC Mapped on: ', network.name)
}

main().catch((err) => {
    console.error(err)
})
