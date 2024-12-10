import { EndpointId } from "@layerzerolabs/lz-definitions";
import { network, deployments, ethers, companionNetworks } from "hardhat";

async function main() {
    if (network.name === "europa-testnet") {
        
        const deploys = await deployments.all();
        const auroraDeployments = await companionNetworks["amoy"].deployments.all();
        const [ signer ] = await ethers.getSigners();
        
        const station = new ethers.Contract(deploys["SKALEStation"].address, deploys["SKALEStation"].abi, signer);

        const addToken = await station.addToken(
            EndpointId.AURORA_V2_TESTNET,
            auroraDeployments["USDC"].address,
            deploys["USDCs"].address,
            true
        );  

        console.log("Add USDC: ", addToken);

    } else {
        
        const deploys = await deployments.all();
        const [ signer ] = await ethers.getSigners();
        const station = new ethers.Contract(deploys["Station"].address, deploys["Station"].abi, signer);

        const addToken = await station.addToken(
            deploys["USDC"].address,
        );

        console.log("Add USDC: ", addToken);
    }
}

main()
    .catch((err) => {
        console.error(err);
        process.exitCode = 1;
    });