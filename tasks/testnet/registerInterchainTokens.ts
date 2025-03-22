import { deployments, ethers, network } from 'hardhat'

async function main() {
    if (network.name === 'europa-testnet') {
        const deploys = await deployments.all()
        const [signer] = await ethers.getSigners()

        const registry = new ethers.Contract(deploys['InterchainRegistry'].address, deploys['NativeSkaleStation'].abi, signer)

        const addETHToNebula = await registry.registerToken(
            "0x000000235ddd06f50cf4b3d38abfe92d8bd31cdbcfe7c2facac6529ec8b40aa4",
            "0xD2Aaa00700000000000000000000000000000000",
            "0x7Dcc444B1B94ACcf24C39C2ff2C0465D640cFC3F",
            "lanky-ill-funny-testnet"
        );
        await addETHToNebula.wait(1);

        const addETHToCalypso = await registry.registerToken(
            "0x000003a14269b5397ec105bb61686794d2f28b732327aca5ede1834df80763d5",
            "0xD2Aaa00700000000000000000000000000000000",
            "0x7Dcc444B1B94ACcf24C39C2ff2C0465D640cFC3F",
            "giant-half-dual-testnet"
        );

        await addETHToCalypso.wait(1);
        

        const addUSDCToNebula = await registry.registerToken(
            "0x000000235ddd06f50cf4b3d38abfe92d8bd31cdbcfe7c2facac6529ec8b40aa4",
            "0x6CE77Fc7970F6984eF3E8748A3826972Ec409Fb9",
            "0xa6be26f2914a17fc4e8d21a1ce2ec4079eeb990c",
            "lanky-ill-funny-testnet"
        );

        await addUSDCToNebula.wait(1);

        const addUSDCToCalypso = await registry.registerToken(
            "0x000003a14269b5397ec105bb61686794d2f28b732327aca5ede1834df80763d5",
            "0x6CE77Fc7970F6984eF3E8748A3826972Ec409Fb9",
            "0xa6be26f2914a17fc4e8d21a1ce2ec4079eeb990c",
            "giant-half-dual-testnet"
        );

        await addUSDCToCalypso.wait(1);

        const addUSDCToTitan = await registry.registerToken(
            "0x000003cd156dcfd9e853083e4af740cb124bb69b07f912ccb938dae5ba601a0f",
            "0x6CE77Fc7970F6984eF3E8748A3826972Ec409Fb9",
            "0xa6be26f2914a17fc4e8d21a1ce2ec4079eeb990c",
            "aware-fake-trim-testnet"
        );

        await addUSDCToTitan.wait(1);
        
    }
}

main().catch((err) => {
    console.error(err)
})
