import { expect } from "chai";
import { Contract, providers, Wallet } from "ethers";
import { deployments, companionNetworks } from "hardhat";
import dotenv from "dotenv";
import { parseUnits } from "ethers/lib/utils";
import { Options } from "@layerzerolabs/lz-v2-utilities";
import { EndpointV2__factory } from "@layerzerolabs/lz-evm-sdk-v2";

dotenv.config();

const privateKey = process.env.PRIVATE_KEY;
if (!privateKey) {
    throw new Error("Missing Private Key");
}

describe("USDC E2E Test", () => {

    let europaStation: Contract;
    let amoyStation: Contract;
    let auroraStation: Contract;

    let europaSigner: Wallet;
    let amoySigner: Wallet;
    let auroraSigner: Wallet;

    let europaUSDC: Contract;
    let amoyUSDC: Contract;
    let auroraUSDC: Contract;

    let amoyProvider: providers.JsonRpcProvider;
    let auroraProvider: providers.JsonRpcProvider;

    beforeEach(async() => {

        const europaDeploys = await deployments.all();
        const amoyDeploys = await companionNetworks["amoy"].deployments.all();
        // const auroraDeploys = await companionNetworks["aurora"].deployments.all();

        europaSigner = new Wallet(privateKey, new providers.JsonRpcProvider("https://testnet.skalenodes.com/v1/juicy-low-small-testnet"));
        
        amoyProvider = new providers.JsonRpcProvider("https://rpc-amoy.polygon.technology");
        amoySigner = new Wallet(privateKey, amoyProvider);

        auroraProvider = new providers.JsonRpcProvider("https://testnet.aurora.dev");
        auroraSigner = new Wallet(privateKey, auroraProvider);
        


        europaStation = new Contract(europaDeploys["SKALEStation"].address, europaDeploys["SKALEStation"].abi, europaSigner);
        amoyStation = new Contract(amoyDeploys["Station"].address, amoyDeploys["Station"].abi, amoySigner);
        // auroraStation = new Contract(auroraDeploys["Station"].address, auroraDeploys["Station"].abi, auroraSigner);
        
        europaUSDC = new Contract(europaDeploys["USDCs"].address, europaDeploys["USDCs"].abi, europaSigner);
        amoyUSDC = new Contract(amoyDeploys["USDC"].address, amoyDeploys["USDC"].abi, amoySigner);
        // auroraUSDC = new Contract(auroraDeploys["USDC"].address, auroraDeploys["USDC"].abi, auroraSigner);
        
    })

    it("Successfully Send 1 USDC from amoy -> Europa", async () => {
        try {

            const initialAllowanceBigInt = await amoyUSDC.allowance(amoySigner.address, amoyStation.address);
            const units = parseUnits("100", 6);
            if (initialAllowanceBigInt < units) {

                const feeData = await amoyProvider.getFeeData();
                const approveUSDC = await amoyUSDC.approve(amoyStation.address, units, {
                    type: 0,
                    gasPrice: feeData.gasPrice
                });
                await approveUSDC.wait(1);
            }

            const options = Options.newOptions()
                .addExecutorLzReceiveOption(1_000_000, 0).toHex().toString();
            

            const quote = await amoyStation.quote(
                [
                    amoyUSDC.address,
                    europaSigner.address,
                    parseUnits("100", 6)
                ],
                options,
                false
            );
            
            const bridge = await amoyStation.bridge(
                [
                    amoyUSDC.address,
                    europaSigner.address,
                    parseUnits("100", 6)
                ], options, {
                value: quote[0],
                type: 0,
                gasLimit: 500_000
            });
            await bridge.wait(1);

            console.log("Bridge: ", bridge);
        } catch (err: any) {
            console.log("Err: ", err.stack);
            throw err;
        }

    })

    // xit("Successfully Send 1 USDC from aurora -> Europa", async () => {
    //     try {

    //         const initialAllowanceBigInt = await auroraUSDC.allowance(auroraSigner.address, auroraStation.address);
    //         const units = parseUnits("1", 6);
    //         if (initialAllowanceBigInt < units) {

    //             const feeData = await auroraProvider.getFeeData();
    //             const approveUSDC = await auroraUSDC.approve(auroraStation.address, units, {
    //                 type: 0,
    //                 gasPrice: feeData.gasPrice
    //             });
    //             await approveUSDC.wait(1);
    //         }

    //         const options = Options.newOptions()
    //             .addExecutorLzReceiveOption(3200000, 0).toHex().toString();
            

    //         const quote = await auroraStation.quote(
    //             [
    //                 auroraUSDC.address,
    //                 europaSigner.address,
    //                 parseUnits("1", 6)
    //             ],
    //             options,
    //             false
    //         );
            
    //         const bridge = await auroraStation.bridge(
    //             [
    //                 auroraUSDC.address,
    //                 europaSigner.address,
    //                 parseUnits("1", 6)
    //             ], options, {
    //             value: quote[0],
    //             type: 0,
    //             gasLimit: 500_000
    //         });
    //         await bridge.wait(1);

    //         console.log("Bridge: ", bridge);
    //     } catch (err: any) {
    //         console.log("Err: ", err.stack);
    //         throw err;
    //     }

    // })
});