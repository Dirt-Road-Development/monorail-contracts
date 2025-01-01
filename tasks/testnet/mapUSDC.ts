import { EndpointId } from "@layerzerolabs/lz-definitions";
import { network, deployments, ethers, companionNetworks } from "hardhat";

async function main() {
    if (network.name === "europa-testnet") {
        
        const deploys = await deployments.all();
        const auroraDeployments = await companionNetworks["aurora"].deployments.all();
        const amoyDeployments = await companionNetworks["amoy"].deployments.all();
        const [ signer ] = await ethers.getSigners();
        
        const station = new ethers.Contract(deploys["SKALEStation"].address, deploys["SKALEStation"].abi, signer);

        // const addToken = await station.addToken(
        //     EndpointId.AURORA_V2_TESTNET,
        //     auroraDeployments["USDC"].address,
        //     deploys["USDCs"].address,
        //     true
        // );  

        // await addToken.wait(1);

        const addToken2 = await station.addToken(
            EndpointId.AMOY_V2_TESTNET,
            amoyDeployments["USDC"].address,
            deploys["USDCs"].address
        );

        await addToken2.wait(1);

        console.log("USDC Added on Europa");

    } else {
        
        const deploys = await deployments.all();
        const [ signer ] = await ethers.getSigners();
        const station = new ethers.Contract(deploys["SatelliteStation"].address, deploys["SatelliteStation"].abi, signer);
        const europaDeployments = await companionNetworks["europa"].deployments.all();

        const addToken = await station.addToken(
            europaDeployments["USDCs"].address,
            deploys["USDC"].address,
        );

        await addToken.wait(1);

        
    }

    console.log("USDC Mapped on: ", network.name);
}

main()
    .catch((err) => {
        console.error(err);
        process.exitCode = 1;
    });