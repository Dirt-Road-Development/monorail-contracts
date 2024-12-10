// import { expect } from "chai";
import { Contract, ethers, providers, Wallet } from "ethers";
import { deployments, companionNetworks } from "hardhat";
import dotenv from "dotenv";
import { formatUnits, getAddress, parseEther, parseUnits } from "ethers/lib/utils";
import { EndpointId } from "@layerzerolabs/lz-definitions";
dotenv.config();

const privateKey = process.env.PRIVATE_KEY;
if (!privateKey) {
    throw new Error("Missing Private Key");
}

describe("USDC E2E Test", () => {

    let europaStation: Contract;
    let europaFeeManager: Contract;

    let auroraStation: Contract;
    let auroraFeeManager: Contract;

    let europaSigner: Wallet;
    let auroraSigner: Wallet;

    let europaUSDC: Contract;
    let auroraUSDC: Contract;

    let auroraProvider: providers.JsonRpcProvider;

    beforeEach(async() => {

        const europaDeploys = await deployments.all();
        const auroraDeploys = await companionNetworks["aurora"].deployments.all();

        europaSigner = new Wallet(privateKey, new providers.JsonRpcProvider("https://testnet.skalenodes.com/v1/juicy-low-small-testnet"));
        auroraProvider = new providers.JsonRpcProvider("https://testnet.aurora.dev");
        auroraSigner = new Wallet(privateKey, auroraProvider);


        europaStation = new Contract(europaDeploys["SKALEStation"].address, europaDeploys["SKALEStation"].abi, europaSigner);
        // europaFeeManager = new Contract(europaDeploys["FeeManager"].address, europaDeploys["FeeManager"].abi, europaSigner);
        europaUSDC = new Contract(europaDeploys["USDCs"].address, europaDeploys["USDCs"].abi, europaSigner);

        auroraStation = new Contract(auroraDeploys["Station"].address, auroraDeploys["Station"].abi, auroraSigner);
        // auroraFeeManager = new Contract(auroraDeploys["FeeManager"].address, auroraDeploys["FeeManager"].abi, auroraSigner);
        auroraUSDC = new Contract(auroraDeploys["USDC"].address, auroraDeploys["USDC"].abi, auroraSigner);

        const r1 = await auroraStation.setPeer(EndpointId.SKALE_V2_TESTNET, ethers.utils.zeroPad(europaStation.address, 32))
        const r2 = await europaStation.setPeer(EndpointId.AURORA_V2_TESTNET, ethers.utils.zeroPad(auroraStation.address, 32))

        await r1.wait(1);
        await r2.wait(1);


    })

    it("Successfully Send 1 USDC from aurora -> Europa", async () => {
        try {

            const initialAllowanceBigInt = await auroraUSDC.allowance(auroraSigner.address, auroraStation.address);
            const initialAllowance = formatUnits(initialAllowanceBigInt, 6);
            console.log("Initial Allowance: ", initialAllowance);
            const units = parseUnits("1", 6);
            console.log("Units: ", units);
            if (initialAllowanceBigInt < units) {
                const feeData = await auroraProvider.getFeeData();
                console.log("Fee Data: ", feeData);
                const approveUSDC = await auroraUSDC.approve(auroraStation.address, units);
                await approveUSDC.wait(1);
            }

            // const options = Options.newOptions().addExecutorLzReceiveOption(200000, 0).toHex().toString()
            const quote = await auroraStation.quote(
                [
                    getAddress(auroraUSDC.address),
                    europaSigner.address,
                    parseUnits("1", 6)
                ],
                "0x",
                false
            );

            // console.log("Post Quote");

            console.log("QUote: ", quote);

            // const bridge = await auroraStation.bridge(
            //     [
            //         getAddress(auroraUSDC.address),
            //         europaSigner.address,
            //         parseUnits("1", 6)
            //     ], "0x", {
            //     value: parseEther("0.001"),
            //     // gasLimit: 500_000
            // });
            // await bridge.wait(1);

            // console.log("Bridge: ", bridge);
        } catch (err: any) {
            console.log("Err: ", err.stack);
            throw err;
        }

    })
});